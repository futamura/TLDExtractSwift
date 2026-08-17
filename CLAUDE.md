# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

TLDExtractSwift — a pure Swift library that extracts the top-level domain, second-level domain, subdomain, and root domain from a hostname or URL using the Public Suffix List (PSL), including IDNA/internationalized domains. Depends on PunycodeSwift (`Punycode` module) for IDNA encoding. Supports macOS, iOS, tvOS, watchOS, and visionOS. Distributed primarily via SPM; also Carthage and CocoaPods (pod name: `TLDExtractSwift`).

## Commands

```bash
# Build and test (SPM)
swift build
swift test

# Run a single test method
swift test --filter TLDExtractSwiftTests/<testMethodName>

# Lint (enforced in CI via swift-format, not SwiftLint)
swift-format lint --ignore-unparsable-files --configuration .swift-format --recursive Sources Tests

# Update the bundled Public Suffix List (rewrites Resources/public_suffix_list.dat)
python update-psl.py

# Fastlane lanes (require `bundle install` first; Ruby/Python managed by mise)
bundle exec fastlane tests            # xcodebuild tests on all platforms (macOS/iOS/tvOS/watchOS/visionOS) + slather coverage
bundle exec fastlane lint_swift       # swift-format lint
bundle exec fastlane build_spm        # swift build + test
bundle exec fastlane build_carthage   # Carthage builds per platform
bundle exec fastlane lint_cocoapods   # pod lib lint
bundle exec fastlane gen_docs         # API docs (currently jazzy into docs/)
bundle exec fastlane set_version      # prompt for version; syncs pbxproj + podspec
bundle exec fastlane bump_version     # patch/minor/major bump; same sync

# Interactive job menu (fzf)
./run.sh
```

Xcode-based test for a specific platform (what CI runs):

```bash
xcodebuild -project TLDExtractSwift.xcodeproj -scheme TLDExtractSwift -destination "platform=macOS" clean test
```

Note: `swift test` requires network access — the test suite initializes `TLDExtract(useFrozenData: false)`, which downloads the live PSL (see below).

## Architecture

Source files in `Sources/`:

- `TLDExtract.swift` — the public API: `TLDExtract` class (`init(useFrozenData:)` loads and parses the PSL; `parse(_:quick:)` returns a `TLDResult?`), the `TLDExtractable` protocol with `URL`/`String` conformances (hostname extraction via regex), and the `TLDResult` struct (`rootDomain` / `topLevelDomain` / `secondLevelDomain` / `subDomain`).
- `Parser.swift` — `PSLParser` (parses raw PSL text into a `PSLDataSet` of exceptions / wildcards / normals) and `TLDParser` (`parseExceptionsAndWildcards` matches rule-based entries; `parseNormals` matches plain suffixes by iterating host components from the right).
- `Model.swift` — `PSLDataSet`, `PSLData` (one PSL rule: exception flag, dot-split parts, priority for rule precedence), `PSLDataPart` (`.wildcard` / `.characters`).
- `SPMPSL.swift` — `SPM_PSL`, a frozen copy of the PSL embedded as a Swift string literal (~10k lines, compiled only under `SWIFT_PACKAGE`).
- `Extension.swift` — internal helpers (`Bundle.current`, `String.isComment`).
- `TLDExtractError.swift` — `TLDExtractError.pslParseError`.
- `TLDExtractSwift.h` — umbrella header for framework (non-SPM) builds.

### PSL data loading (two build paths)

`TLDExtract.init` branches on `#if SWIFT_PACKAGE`:

- **SPM build**: `useFrozenData: true` uses the embedded `SPM_PSL` string; `false` (default) synchronously downloads https://publicsuffix.org/list/public_suffix_list.dat at init. During parsing, each PSL line is additionally registered in its IDNA-encoded form via PunycodeSwift (`line.idnaEncoded`).
- **Framework build** (Xcode/Carthage/CocoaPods): loads `Resources/public_suffix_list.dat` (or `public_suffix_list_frozen.dat` when `useFrozenData: true`) from the framework bundle via `Bundle.current`. The podspec ships these via `s.resources = "Resources/*.dat"`. No IDNA pass at parse time — punycoded rules are pre-baked into the `.dat` file.

`update-psl.py` regenerates `Resources/public_suffix_list.dat`: downloads the latest PSL, strips comments and blank lines, and inserts a punycode-encoded variant after each internationalized rule. It does not touch `SPMPSL.swift` or `public_suffix_list_frozen.dat` — those are frozen snapshots.

Tests live in `Tests/TLDExtractSwiftTests.swift` (single XCTest file; SPM test target name is `TLDExtractSwiftTests`).

## Versioning and release

- Single source of truth for the version: `MARKETING_VERSION` in `TLDExtractSwift.xcodeproj/project.pbxproj`. Never edit versions by hand — use `fastlane set_version` / `bump_version`, which also sync `TLDExtractSwift.podspec`.
- Branch flow: work on `develop`, PR into `main`.
- CI (`.github/workflows/main.yml`) runs on push and pull request to `main`/`develop`: swift-format lint → per-platform xcodebuild tests (simulator devices resolved at runtime via `simctl`) → SPM (macOS) → pod lib lint. It does not release. Carthage builds are not CI-verified (best-effort compatibility via the Xcode project). The `CI Success` job aggregates all results and is the required status check on `main`.
- Docs: currently jazzy-generated into a committed `docs/` directory, served by GitHub Pages via `.github/workflows/static.yml` on push to `main`.
- Releasing is a separate, explicit step: push a bare version tag (e.g. `3.0.1`) matching `MARKETING_VERSION`. `.github/workflows/release.yml` then verifies the tag against the project version, creates a GitHub Release (notes taken from the tag's `CHANGELOG.md` section, falling back to generated notes), and pushes to CocoaPods trunk.
- Version tags are immutable: the release workflow fails if the tag or trunk version already exists. To re-release, bump the version — never delete/re-push a tag.
- Keep `CHANGELOG.md` (Keep a Changelog format) current: user-facing changes go under **Unreleased**; when releasing, rename that section to the new version with the date and add its compare link. The release workflow extracts this section for the GitHub Release notes.
- CocoaPods trunk becomes read-only on 2026-12-02; CocoaPods distribution ends then. After that date, remove the `lint_cocoapods` job from `main.yml` and the `publish_cocoapods` job from `release.yml`.
