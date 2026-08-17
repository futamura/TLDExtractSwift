# Contributing to TLDExtractSwift

Thanks for your interest in contributing! This document explains how to set up a development environment and submit changes.

## Development setup

Requirements:

- Xcode (see the versions exercised in [CI](.github/workflows/main.yml))
- [mise](https://mise.jdx.dev/) for Ruby/Python toolchain management (optional but recommended)

```bash
git clone https://github.com/futamura/TLDExtractSwift.git
cd TLDExtractSwift
mise install        # installs the Ruby/Python versions from .mise.toml
bundle install      # installs fastlane and other development gems
```

## Building and testing

```bash
# SPM
swift build
swift test

# Run a single test method
swift test --filter TLDExtractSwiftTests/<testMethodName>

# Xcode-based tests for a specific platform (what CI runs)
xcodebuild -project TLDExtractSwift.xcodeproj -scheme TLDExtractSwift -destination "platform=macOS" clean test
```

Note: the test suite downloads the live Public Suffix List, so tests require network access.

Fastlane lanes are available for the full matrix (`bundle exec fastlane tests`), linting (`lint_swift`), and more — or use the interactive menu: `./run.sh`.

## Updating the Public Suffix List

The bundled Public Suffix List (`Resources/public_suffix_list.dat`) is regenerated with:

```bash
python update-psl.py
```

## Linting

CI enforces formatting with [swift-format](https://github.com/swiftlang/swift-format):

```bash
swift-format lint --ignore-unparsable-files --configuration .swift-format --recursive Sources Tests
```

Run this before pushing; the `Lint Code` job fails on violations.

## Branches and pull requests

- Base your work on `develop` and open pull requests against `develop`.
- `main` receives merges from `develop`; releases are tagged from `main`.
- Keep pull requests focused. Include tests for behavior changes — the test suite lives in `Tests/TLDExtractSwiftTests.swift`.
- All CI checks (the `CI Success` gate) must pass before merging.

## Versioning and releases

Releases are handled by maintainers. The version's single source of truth is `MARKETING_VERSION` in `TLDExtractSwift.xcodeproj/project.pbxproj`; it is synced to the podspec via `bundle exec fastlane set_version` / `bump_version`. Do not edit version numbers by hand in a pull request.

## Reporting issues

Use the [issue templates](https://github.com/futamura/TLDExtractSwift/issues/new/choose). For security vulnerabilities, see [SECURITY.md](SECURITY.md) — do not open a public issue.
