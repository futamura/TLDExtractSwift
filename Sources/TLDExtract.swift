//
//  TLDExtract.swift
//  TLDExtract
//
//  Created by Kojiro futamura on 2018/11/16.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// TLDExtract is a class that extracts the top-level domain (TLD) from a given hostname.
/// It can fetch the public suffix list from a remote source or use a frozen dataset.
///
/// - Parameters:
///   - useFrozenData: A Boolean value indicating whether to use a pre-fetched public suffix list.
///
/// - Throws:
///   - TLDExtractError.pslParseError if there is an error while parsing the public suffix list.
public class TLDExtract {

    private let tldParser: TLDParser

    public init(useFrozenData: Bool = false) throws {
        #if SWIFT_PACKAGE

        var data: Data
        if useFrozenData {
            data = SPM_PSL.data(using: .utf8)!
        } else {
            let url: URL = URL(string: "https://publicsuffix.org/list/public_suffix_list.dat")!
            data = try Data(contentsOf: url)
        }

        let dataSet: PSLDataSet = try PSLParser().parse(data: data)
        self.tldParser = TLDParser(dataSet: dataSet)

        #else

        let url: URL = Bundle.current.url(
            forResource: useFrozenData ? "public_suffix_list_frozen" : "public_suffix_list",
            withExtension: "dat"
        )!
        let data: Data = try Data(contentsOf: url)
        let dataSet = try PSLParser().parse(data: data)
        self.tldParser = TLDParser(dataSet: dataSet)

        #endif
    }

    /// Parameters:
    ///   - host: Hostname to be extracted
    ///   - quick: If true, parse only normal data excluding exceptions and wildcards
    public func parse<T: TLDExtractable>(_ input: T, quick: Bool = false) -> TLDResult? {
        guard let host: String = input.hostname else { return nil }
        if quick {
            return self.tldParser.parseNormals(host: host)
        } else {
            return self.tldParser.parseExceptionsAndWildcards(host: host) ?? self.tldParser.parseNormals(host: host)
        }
    }
}

/// A protocol that requires conforming types to provide a hostname as a String.
/// This protocol is used to extract top-level domains from various input types.
public protocol TLDExtractable {
    var hostname: String? { get }
}

/// An extension of `URL` that conforms to the `TLDExtractable` protocol.
/// This extension provides functionality to initialize a `URL` from a Unicode string
/// and to extract the hostname from the URL.
///
/// - Parameters:
///   - unicodeString: A string that may contain a URL encoded in Unicode format.
extension URL: TLDExtractable {

    init?(unicodeString: String) {
        if let encodedUrl: String = unicodeString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            self.init(string: encodedUrl)
        } else {
            self.init(string: unicodeString)
        }
    }

    /// The hostname extracted from the URL.
    /// - Returns: A string representing the hostname, or `nil` if it cannot be extracted.
    public var hostname: String? {
        let result: String? = self.absoluteString.removingPercentEncoding?.hostname
        return result
    }
}

/// An extension of `String` that conforms to the `TLDExtractable` protocol.
/// This extension provides functionality to extract the hostname from a string,
/// which may represent a URL or a domain name.
///
/// The `hostname` property uses regular expressions to identify and extract
/// the hostname from the string. It checks for the presence of a scheme (e.g., http://)
/// and handles both URLs and plain domain names.
///
/// - Returns: A string representing the hostname, or `nil` if it cannot be extracted.
extension String: TLDExtractable {
    public var hostname: String? {
        let schemePattern: String = "^(\\p{L}+:)?//"
        let hostPattern: String = "([0-9\\p{L}][0-9\\p{L}-]{1,61}\\.?)?   ([\\p{L}-]*  [0-9\\p{L}]+)  (?!.*:$).*$".replace(" ", "")
        if self.matches(schemePattern) {
            let components: [String] = self.replace(schemePattern, "").components(separatedBy: "/")
            guard let component: String = components.first, !component.isEmpty else { return nil }
            return component
        } else if self.matches("^\(hostPattern)") {
            let components: [String] = self.replace(schemePattern, "").components(separatedBy: "/")
            guard let component: String = components.first, !component.isEmpty else { return nil }
            return component
        } else {
            return URL(string: self)?.host
        }
    }
}

/// This extension provides additional functionality for the `String` type,
/// specifically for pattern matching and replacing substrings using regular expressions.
///
/// - Methods:
///   - matches(_:) : Checks if the string matches the given regular expression pattern.
///   - replace(_:_:): Replaces occurrences of the specified pattern in the string with a given replacement string.
fileprivate extension String {
    func matches(_ pattern: String) -> Bool {
        guard let regex: NSRegularExpression = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.matches(in: self, range: NSRange(location: 0, length: self.count)).count > 0
    }

    func replace(_ pattern: String, _ replacement: String) -> String {
        return self.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}

/// A structure that represents the result of a top-level domain extraction.
///
/// This structure contains the components of a domain name, including:
/// - `rootDomain`: The root domain of the URL or domain name.
/// - `topLevelDomain`: The top-level domain (TLD) of the URL or domain name.
/// - `secondLevelDomain`: The second-level domain (SLD) of the URL or domain name.
/// - `subDomain`: The subdomain of the URL or domain name.
public struct TLDResult {
    public let rootDomain: String?
    public let topLevelDomain: String?
    public let secondLevelDomain: String?
    public let subDomain: String?
}
