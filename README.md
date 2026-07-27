[![Swift Package Manager compatible](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange)](https://github.com/futamura/TLDExtractSwift)
![Carthage](https://img.shields.io/badge/Carthage-Compatible-blue)
[![Cocoapods Version](https://img.shields.io/cocoapods/v/TLDExtractSwift.svg)](https://cocoapods.org/pods/TLDExtractSwift)
[![Cocoapods Platform](https://img.shields.io/cocoapods/p/TLDExtractSwift.svg)](https://cocoadocs.org/docsets/TLDExtract)
[![Build](https://github.com/futamura/TLDExtractSwift/actions/workflows/main.yml/badge.svg)](https://github.com/futamura/TLDExtractSwift/actions/workflows/main.yml)
[![codecov](https://codecov.io/gh/gumob/TLDExtractSwift/branch/master/graph/badge.svg)](https://codecov.io/gh/gumob/TLDExtractSwift)
![Language](https://img.shields.io/badge/Language-Swift%205.0-orange.svg)
![Packagist](https://img.shields.io/packagist/l/doctrine/orm.svg)

# TLDExtract
<code>TLDExtract</code> is a pure Swift library to allows you to get the public suffix of a domain name using [the Public Suffix List](http://www.publicsuffix.org). You can find alternatives for other languages at [publicsuffix.org](https://publicsuffix.org/learn/).<br/>

## What are domains?

Domain names are the unique, human-readable Internet addresses of websites. They are made up of three parts: a top-level domain (a.k.a. TLD), a second-level domain name, and an optional subdomain.

<img src="https://raw.githubusercontent.com/futamura/TLDExtractSwift/main/Metadata/domain-diagram.webp" alt="drawing" width="100%" style="width:100%; max-width: 100%;"/>

## Changes in 3.0.0

### Breaking changes

- ‼️ Library name changed from ~~`TLDExtract`~~ to **`TLDExtractSwift`** to resolve namespace conflicts. For more details, please check the issue ([apple/swift#56573](https://github.com/apple/swift/issues/56573)).
  
  Please don't forget to update your source code.

  ```diff
  - import TLDExtract
  + import TLDExtractSwift
  ```

### Other changes
- Dropped support for Swift 4.
- Added watchOS and visionOS to supported platforms.
- Changed supported versions for macOS, iOS, and tvOS to match Xcode 15.4.


## Feature

- Extract root domain, top level domain, second level domain, subdomain from url and hostname
- Foundation URL and String support
- IDNA support
- Multi platform support

## Requirements

- macOS 10.13 or later
- iOS 12.0 or later
- tvOS 12.0 or later
- watchOS 4.0 or later
- visionOS 1.0 or later
- Swift 5.0 or later

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file.

- macOS, iOS, tvOS, watchOS, visionOS, and Swift 5

    ```swift
    dependencies: [
        .package(url: "https://github.com/futamura/TLDExtractSwift.git", .upToNextMajor(from: "3.0.0"))
    ]
    ```

- macOS, iOS, tvOS, and Swift 5

    ```swift
    dependencies: [
        .package(url: "https://github.com/futamura/TLDExtractSwift.git", .upToNextMajor(from: "2.1.1"))
    ]
    ```

### Carthage

Add the following to your `Cartfile` and follow [these instructions](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).

- macOS, iOS, tvOS, watchOS, visionOS, and Swift 5

    ```
    github "futamura/TLDExtractSwift" ~> 3.0
    ```
- macOS, iOS, tvOS, and Swift 5

    ```
    github "futamura/TLDExtractSwift" ~> 2.0
    ```
- macOS, iOS, tvOS, and Swift 4

    ```
    github "futamura/TLDExtractSwift" ~> 1.0
    ```

Do not forget to include Punycode.framework. Otherwise it will fail to build the application.<br/>

<img src="https://raw.githubusercontent.com/futamura/TLDExtractSwift/main/Metadata/carthage-xcode-config.jpg" alt="drawing" width="480" style="width:100%; max-width: 480px;"/>

### CocoaPods

To integrate TLDExtract into your project, add the following to your `Podfile`.

- macOS, iOS, tvOS, watchOS, visionOS, and Swift 5.0

    ```ruby
    pod 'TLDExtractSwift', '~> 3.0'
    ```
- macOS, iOS, tvOS, and Swift 5.0

    ```ruby
    pod 'TLDExtract', '~> 2.0'
    ```
- macOS, iOS, tvOS, and Swift 4.2

    ```ruby
    pod 'TLDExtract', '~> 1.0'
    ```

## Usage

Full documentation is available at [https://futamura.github.io/TLDExtractSwift/swiftdoc/](https://futamura.github.io/TLDExtractSwift/swiftdoc/).

### Initialization

Basic initialization code. Exceptions will not be raised unless [the Public Suffix List on the server](https://publicsuffix.org/list/public_suffix_list.dat) is broken.

```swift
import TLDExtractSwift

let extractor = try! TLDExtract()
```

A safer initialization code to avoid errors by using the frozen Public Suffix List:<br/>

```swift
import TLDExtractSwift

let extractor = try! TLDExtract(useFrozenData: true)

```
*The Public Suffix List is updated every time the framework is built. By setting userFrozenData to true, TLDExtract loads data which checked out from the repository.

### Extraction

#### Passing argument as String

Extract an url:

```swift
let urlString: String = "https://www.github.com/futamura/TLDExtract"
guard let result: TLDResult = extractor.parse(urlString) else { return }

print(result.rootDomain)        // Optional("github.com")
print(result.topLevelDomain)    // Optional("com")
print(result.secondLevelDomain) // Optional("github")
print(result.subDomain)         // Optional("www")
```

Extract a hostname:

```swift
let hostname: String = "gumob.com"
guard let result: TLDResult = extractor.parse(hostname) else { return }

print(result.rootDomain)        // Optional("gumob.com")
print(result.topLevelDomain)    // Optional("com")
print(result.secondLevelDomain) // Optional("gumob")
print(result.subDomain)         // nil
```

Extract an unicode hostname:

```swift
let hostname: String = "www.ラーメン.寿司.co.jp"
guard let result: TLDResult = extractor.parse(hostname) else { return }

print(result.rootDomain)        // Optional("寿司.co.jp")
print(result.topLevelDomain)    // Optional("co.jp")
print(result.secondLevelDomain) // Optional("寿司")
print(result.subDomain)         // Optional("www.ラーメン")
```

Extract a punycoded hostname (Same as above):

```swift
let hostname: String = "www.xn--4dkp5a8a.xn--sprr0q.co.jp")"
guard let result: TLDResult = extractor.parse(hostname) else { return }

print(result.rootDomain)        // Optional("xn--sprr0q.co.jp")
print(result.topLevelDomain)    // Optional("co.jp")
print(result.secondLevelDomain) // Optional("xn--sprr0q")
print(result.subDomain)         // Optional("www.xn--4dkp5a8a")
```

#### Passing argument as Foundation URL

Extract an unicode url: <br/>
URL class in Foundation Framework does not support unicode URLs by default. You can use URL extension as a workaround

```swift
let urlString: String = "http://www.ラーメン.寿司.co.jp"
let url: URL = URL(unicodeString: urlString)
guard let result: TLDResult = extractor.parse(url) else { return }

print(result.rootDomain)        // Optional("www.ラーメン.寿司.co.jp")
print(result.topLevelDomain)    // Optional("co.jp")
print(result.secondLevelDomain) // Optional("寿司")
print(result.subDomain)         // Optional("www.ラーメン")
```

Encode an url by passing argument as percent encoded string (Same as above):

```swift
let urlString: String = "http://www.ラーメン.寿司.co.jp".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
let url: URL = URL(string: urlString)
print(urlString)                // http://www.%E3%83%A9%E3%83%BC%E3%83%A1%E3%83%B3.%E5%AF%BF%E5%8F%B8.co.jp

guard let result: TLDResult = extractor.parse(url) else { return }

print(result.rootDomain)        // Optional("www.ラーメン.寿司.co.jp")
print(result.topLevelDomain)    // Optional("co.jp")
print(result.secondLevelDomain) // Optional("寿司")
print(result.subDomain)         // Optional("www.ラーメン")
```

Encode an unicode url by using [`Punycode`](https://github.com/futamura/Punycode) Framework:

```swift
import Punycode

let urlString: String = "http://www.ラーメン.寿司.co.jp".idnaEncoded!
let url: URL = URL(string: urlString)
print(urlString)                // http://www.xn--4dkp5a8a.xn--sprr0q.co.jp

guard let result: TLDResult = extractor.parse(url) else { return }

print(result.rootDomain)        // Optional("xn--sprr0q.co.jp")
print(result.topLevelDomain)    // Optional("co.jp")
print(result.secondLevelDomain) // Optional("xn--sprr0q")
print(result.subDomain)         // Optional("www.xn--4dkp5a8a")
```

## Copyright

TLDExtract is released under MIT license, which means you can modify it, redistribute it or use it however you like.
