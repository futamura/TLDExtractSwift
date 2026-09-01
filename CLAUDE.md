# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

TLDExtractSwift — a pure Swift library that extracts the top-level domain, second-level domain, subdomain, and root domain from a hostname or URL using the Public Suffix List (PSL), including IDNA/internationalized domains. Depends on PunycodeSwift (`Punycode` module) for IDNA encoding. Supports macOS, iOS, tvOS, watchOS, visionOS, and Linux (SPM builds). Distributed via SPM. Carthage compatibility is best-effort (not CI-verified); CocoaPods distribution has ended (3.0.0 is the last version published under the pod name `TLDExtractSwift`).

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
bundle exec fastlane gen_docs         # DocC static site into docc-site/ (via scripts/gen_docs.sh)
bundle exec fastlane set_version      # prompt for version; sets MARKETING_VERSION in the pbxproj
bundle exec fastlane set_version version:4.0.2   # non-interactive form
bundle exec fastlane bump_version     # patch/minor/major bump; same effect
bundle exec fastlane bump_version type:patch     # non-interactive form

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
- **Framework build** (Xcode/Carthage): loads `Resources/public_suffix_list.dat` (or `public_suffix_list_frozen.dat` when `useFrozenData: true`) from the framework bundle via `Bundle.current`. No IDNA pass at parse time — punycoded rules are pre-baked into the `.dat` file.

`update-psl.py` downloads the latest PSL, strips comments and blank lines, inserts a punycode-encoded variant after each internationalized rule, and writes the result to all three bundled copies: `Resources/public_suffix_list.dat`, `Resources/public_suffix_list_frozen.dat`, and the `SPM_PSL` literal in `Sources/SPMPSL.swift` (substituted in place, so the file's header is preserved). The three therefore hold identical data; `useFrozenData` selects between a bundled snapshot and a live download only on the SPM path.

`.github/workflows/update-psl.yml` runs the script weekly (Monday 03:00 UTC, plus manual dispatch). When the list changed it runs `swift test` in the `swift:6.2` container against the refreshed data and opens a pull request against `develop` only if those tests pass. That in-workflow run is a gate in its own right, and it is worth keeping green for that reason: a failure there means no pull request at all, so a flaky test silently costs a week of updates.

The pull request is opened with the `PSL_UPDATE_TOKEN` secret, a fine-grained PAT scoped to this repository (Contents and Pull requests read and write) that was registered on 2026-09-01 and **expires on 2027-09-01**. Renew it before then: the workflow reads `${{ secrets.PSL_UPDATE_TOKEN || secrets.GITHUB_TOKEN }}`, and `||` falls back only on an empty value, so an expired token is still used, fails with 401, and stops the weekly refresh rather than degrading to `GITHUB_TOKEN`. The fallback exists because a pull request opened with `GITHUB_TOKEN` does not trigger workflows and therefore carries no checks; if you ever see such a pull request, the secret is gone or expired.

Tests live in `Tests/TLDExtractSwiftTests.swift` (single XCTest file; SPM test target name is `TLDExtractSwiftTests`). Note how little of it XCTest actually discovers: `testExtractableString`, `testExtractableURL`, `testTLDExtractString` and `testTLDExtractURL` take `file`/`line` arguments, so they are not `() -> Void` and never run as tests of their own. The `testMeasure*` methods are their only callers, which makes those four blocks the entire coverage of the extraction paths — deleting or platform-gating a measurement silently removes it. Run the suite and check the executed count (six, not two) after touching them.

## Versioning and release

- Single source of truth for the version: `MARKETING_VERSION` in `TLDExtractSwift.xcodeproj/project.pbxproj`. Never edit versions by hand — use `fastlane set_version` / `bump_version`. Both lanes prompt only when stdin is a TTY; without one, pass `version:` / `type:` or the lane fails rather than silently leaving the version untouched.
- Branch flow: work on `develop`, PR into `main`.
- CI (`.github/workflows/main.yml`) runs on push and pull request to `main`/`develop`: swift-format lint → per-platform xcodebuild tests (simulator devices resolved at runtime via `simctl`) → SPM (macOS + Linux via the official Swift container). It does not release. Carthage builds are not CI-verified (best-effort compatibility via the Xcode project). The `CI Success` job aggregates all results and is the required status check on `main`.
- The simulator jobs flake in two ways, neither of which is a problem with the code: they finish every test and then abort during teardown with exit code 134, or they hang and get cancelled on the job's `timeout-minutes` (15 for the simulator matrix, 10 for the macOS, Catalyst and SPM jobs). The 134 abort is retried once by the job itself; any other non-zero status fails immediately, so a real failure is never retried into a pass. A timeout is not retried. `gh pr checks` reports both as `fail`; `gh api repos/futamura/TLDExtractSwift/actions/jobs/<job-id> --jq .conclusion` tells them apart, since a timeout shows `cancelled` and the abort shows `failure`. Rerun with `gh run rerun <run-id> --failed` rather than debugging the tests.
- Performance measurements are gated on the platform, and the reason is not cosmetic. Apple's XCTest treats a relative standard deviation over its 10% limit as information when no baseline is recorded, and none is; swift-corelibs-xctest fails the test instead and exposes no API to relax the limit (`measureMetrics(_:automaticallyStartMeasuring:file:line:for:)` is all there is, and `maxRelativeStandardDeviation` is internal). One slow iteration on a shared runner is enough — a 0.448s outlier among nine iterations between 0.104s and 0.137s produced a 71% deviation and a red build — and because the refresh workflow gates on `swift test` in a Linux container, that cost a week of Public Suffix List updates in August 2026. `measureIfSupported` therefore runs the blocks untimed on Linux, keeping the assertions inside them. Reproduce Linux behaviour locally with `docker run --rm -v "$PWD:/package" -w /package swift:6.2 swift test -c debug`, and mind that piping it through `tail` hides the exit status.
- Documentation (`.github/workflows/docs.yml`) builds the DocC site with `scripts/gen_docs.sh` (symbolgraph-extract with `-emit-extension-block-symbols` — required because part of the public API is extensions on URL/String — then `docc convert`) and deploys it to GitHub Pages on every push to `main`. The site is not tracked in git; `docs/` no longer exists.
- Swift Package Index: `.spi.yml` has SPI build and host its own copy of the DocC documentation (`custom_documentation_parameters: [--include-extended-types]` is required — without it the extensions on URL/String, which are part of the public API, are dropped) and sets the author line via `metadata.authors`, which SPI would otherwise derive from the commit history and credit to the former `gumob` handle. SPI renders `metadata.authors` verbatim, so the value has to be a complete sentence: the `Written by ` prefix and the full stop are added only to the line it derives itself.
- Changes to `.spi.yml` reach the package page slowly, and this is by design rather than a fault to chase: `Analyze.throttle` in SwiftPackageIndex-Server keeps the stored default-branch version until its commit is older than `Constants.branchVersionRefreshDelay` (24 hours), and the author line reads `defaultBranchVersion.spiManifest`. Merging again does not restart that clock — it runs from the commit SPI already holds — but the refresh, when it happens, picks up the newest commit, so queued changes land together. Tags are not throttled, which is why a release shows up on the page the same day.
- Releasing is a separate, explicit step: push a bare version tag (e.g. `4.0.1`) matching `MARKETING_VERSION`. `.github/workflows/release.yml` then verifies the tag against the project version and creates a GitHub Release (notes taken from the tag's `CHANGELOG.md` section, falling back to generated notes). Use `./run.sh` → "Github - Update tag" to create the tag (it refuses to retag an existing version).
- Version tags are immutable: the release workflow fails if the tag already exists. To re-release, bump the version — never delete/re-push a tag.
- Keep `CHANGELOG.md` (Keep a Changelog format) current: user-facing changes go under **Unreleased**; when releasing, rename that section to the new version with the date and add its compare link. The release workflow extracts this section for the GitHub Release notes.
