# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A weekly workflow that refreshes the bundled Public Suffix List, runs the test suite against the new data, and opens a pull request when it changed.
- Swift Package Index listing, with an `.spi.yml` that has SPI build and host the DocC documentation alongside the GitHub Pages site. The README gains the SPI Swift version and platform compatibility badges.

### Changed

- The bundled Public Suffix List is refreshed. `public_suffix_list_frozen.dat` and the `SPM_PSL` literal had not been regenerated since August 2024, so `useFrozenData: true` was resolving against a two-year-old list; `update-psl.py` now writes all three bundled copies from a single download.
- `update-psl.py` requires Python 3 (the Python 2 branch is gone) and reports any rule it cannot punycode instead of failing silently.

### Fixed

- Maintainer tooling: the `set_version` / `bump_version` fastlane lanes accept `version:` / `type:` arguments and fail without a TTY instead of silently leaving the version untouched, and the version format check is anchored so that values such as `1a2b3` are rejected instead of written to the project.

## [4.0.1] - 2026-08-18

### Changed

- Carthage: the Punycode dependency in the Cartfile is raised to 4.0, and the resolved version is updated to PunycodeSwift 4.0.1.

### Fixed

- Framework builds set `APPLICATION_EXTENSION_API_ONLY`, so linking the framework from an app extension no longer emits a "not safe for use in application extensions" warning ([#10](https://github.com/futamura/TLDExtractSwift/issues/10)). Not applicable to SPM consumers.

### Removed

- The Xcode script build phases that reformatted sources and regenerated the bundled Public Suffix List on every build. Builds no longer mutate the working tree (and no longer emit script-sandboxing warnings); refresh the bundled list explicitly with `python update-psl.py`.
- Leftover SwiftLint and Hound configuration (linting is enforced via swift-format) and the obsolete `.swift-version` file.

## [4.0.0] - 2026-08-18

### Added

- Linux support, verified by CI (`swift build` / `swift test` on the official Swift container).
- GitHub Releases are now created automatically when a version tag is pushed.
- `CI Success` aggregate check for branch protection.
- Community files: `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, issue and PR templates.

### Changed

- **Breaking**: `Package.swift` requires swift-tools 5.9 (Xcode 15 or later for SPM consumers) and declares explicit platforms: macOS 10.13, iOS 12, tvOS 12, watchOS 4, visionOS 1.
- **Breaking**: the PunycodeSwift dependency is raised to 4.0 (`.upToNextMajor(from: "4.0.0")`), which adds the URL-aware `idnaEncodedURL` / `idnaDecodedURL` API.
- Product bundle identifiers renamed from `com.gumob.*` to `dev.futamura.*`, completing the account rename.
- CI runs on pushes and pull requests to `main` and `develop`, on current macOS runner images, resolving simulator destinations at runtime.
- API documentation migrated from jazzy to DocC, built and deployed to GitHub Pages by CI; the generated site is no longer tracked in the repository. New URL: <https://futamura.github.io/TLDExtractSwift/documentation/tldextractswift/>.
- Releasing is now a separate tag-triggered workflow that verifies the tag against the project version before publishing. Version tags are immutable.
- Development tooling: Ruby 3.4 / Bundler 2.7, gems updated to clear all outstanding Dependabot alerts.

### Fixed

- The README example that applied `idnaEncoded` to a full URL (which mangles the scheme into the first label) now encodes the host component correctly ([#8](https://github.com/futamura/TLDExtractSwift/issues/8)).

### Deprecated

- Carthage support is best-effort and no longer CI-verified.

### Removed

- CocoaPods publishing: 3.0.0 is the last version available as the `TLDExtractSwift` pod (the trunk becomes read-only on 2026-12-02 anyway). Later versions are distributed via Swift Package Manager (and Carthage on a best-effort basis). The podspec, the pod lint CI job, and the trunk push in the release workflow are removed.

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

[Unreleased]: https://github.com/futamura/TLDExtractSwift/compare/4.0.1...HEAD
[4.0.1]: https://github.com/futamura/TLDExtractSwift/compare/4.0.0...4.0.1
[4.0.0]: https://github.com/futamura/TLDExtractSwift/compare/3.0.0...4.0.0
[3.0.0]: https://github.com/futamura/TLDExtractSwift/compare/2.1.1...3.0.0
[2.1.1]: https://github.com/futamura/TLDExtractSwift/compare/2.1.0...2.1.1
[2.1.0]: https://github.com/futamura/TLDExtractSwift/compare/2.0.0...2.1.0
[2.0.0]: https://github.com/futamura/TLDExtractSwift/compare/1.0.1...2.0.0
[1.0.1]: https://github.com/futamura/TLDExtractSwift/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/futamura/TLDExtractSwift/releases/tag/1.0.0
