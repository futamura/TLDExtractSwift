# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- GitHub Releases are now created automatically when a version tag is pushed.
- `CI Success` aggregate check for branch protection.
- Community files: `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, issue and PR templates.

### Changed

- CI runs on pushes and pull requests to `main` and `develop`, on current macOS runner images, resolving simulator destinations at runtime.
- Releasing is now a separate tag-triggered workflow that verifies the tag against the project version before publishing. Version tags are immutable.
- Development tooling: Ruby 3.4 / Bundler 2.7, gems updated.

### Deprecated

- CocoaPods distribution ends when the trunk becomes read-only on 2026-12-02. Migrate to Swift Package Manager.
- Carthage support is best-effort and no longer CI-verified.

## [3.0.0] - 2024-08-28

### Added

- watchOS and visionOS support.

### Changed

- **Breaking**: Module renamed from `TLDExtract` to `TLDExtractSwift` to resolve a namespace conflict between the module and its main class ([apple/swift#56573](https://github.com/apple/swift/issues/56573)). Update your imports: `import TLDExtractSwift`.
- Raised deployment targets: macOS 10.13, iOS 12.0, tvOS 12.0.
- Dropped Swift 4 support.

## [2.1.1] - 2024-08-23

### Changed

- Aligned platforms and dependencies in `Package.swift` with the podspec.
- Project maintenance: CI and dependency updates.

## [2.1.0] - 2020-06-24

### Added

- Swift Package Manager support, including an embedded Public Suffix List snapshot for SPM builds.

### Changed

- Tooling and CI maintenance (SwiftLint, gems, CocoaPods lint settings).

## [2.0.0] - 2019-08-09

### Added

- Swift 5 support.
- tvOS support (tvOS 11 and earlier included).

## [1.0.1] - 2018-11-21

### Fixed

- Documentation and packaging fixes.

## [1.0.0] - 2018-11-21

### Added

- Initial release: extraction of root domain, top-level domain, second-level domain, and subdomain from URLs and hostnames using the Public Suffix List, with IDNA support.

[Unreleased]: https://github.com/futamura/TLDExtractSwift/compare/3.0.0...HEAD
[3.0.0]: https://github.com/futamura/TLDExtractSwift/compare/2.1.1...3.0.0
[2.1.1]: https://github.com/futamura/TLDExtractSwift/compare/2.1.0...2.1.1
[2.1.0]: https://github.com/futamura/TLDExtractSwift/compare/2.0.0...2.1.0
[2.0.0]: https://github.com/futamura/TLDExtractSwift/compare/1.0.1...2.0.0
[1.0.1]: https://github.com/futamura/TLDExtractSwift/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/futamura/TLDExtractSwift/releases/tag/1.0.0
