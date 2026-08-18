fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### run_all

```sh
[bundle exec] fastlane run_all
```

Run all jobs

### set_version

```sh
[bundle exec] fastlane set_version
```

Set version number

### bump_version

```sh
[bundle exec] fastlane bump_version
```

Bump version number

### lint_swift

```sh
[bundle exec] fastlane lint_swift
```

Lint codes with swift-format

### tests

```sh
[bundle exec] fastlane tests
```

Run all tests

### build_spm

```sh
[bundle exec] fastlane build_spm
```

Lint Swift Package Manager

### build_carthage

```sh
[bundle exec] fastlane build_carthage
```

Build Carthage

### gen_docs

```sh
[bundle exec] fastlane gen_docs
```

Generate DocC documentation site into docc-site/

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
