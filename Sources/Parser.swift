//
//  Created by Kojiro futamura on 2018/11/16.
//

import Foundation

#if SWIFT_PACKAGE
import Punycode
#endif

internal class PSLParser {

    var exceptions: [PSLData] = [PSLData]()
    var wildcards: [PSLData] = [PSLData]()
    var normals: Set<String> = Set<String>()

    internal func addLine(_ line: String) {
        if line.contains("*") {
            self.wildcards.append(PSLData(raw: line))
        } else if line.starts(with: "!") {
            self.exceptions.append(PSLData(raw: line))
        } else if !line.isComment && !line.isEmpty {
            self.normals.insert(line)
        }
    }

    internal func parse(data: Data?) throws -> PSLDataSet {
        guard let data: Data = data, let str: String = String(data: data, encoding: .utf8), str.count > 0 else {
            throw TLDExtractError.pslParseError(message: nil)
        }
        for line: String in str.components(separatedBy: .newlines) {
            if line.isComment { continue }
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            self.addLine(line)

            // this does the same thing as update-psl.py
            #if SWIFT_PACKAGE
            if let encoded: String = line.idnaEncoded {
                self.addLine(encoded)
            }
            #endif
        }
        /// Longest rules first, so the first match is the one that prevails
        return PSLDataSet(
            exceptions: exceptions.sorted(by: >),
            wildcards: wildcards.sorted(by: >),
            normals: normals
        )
    }
}

internal class TLDParser {

    private let pslDataSet: PSLDataSet

    internal init(dataSet: PSLDataSet) {
        self.pslDataSet = dataSet
    }

    /// Applies the rule that prevails for the host: an exception if one matches,
    /// otherwise the longest matching rule, a wildcard winning a tie with a normal rule
    internal func parse(host: String) -> TLDResult? {
        let hostComponents: [String] = host.lowercased().components(separatedBy: ".")
        let matchClosure: (PSLData) -> Bool = { $0.matches(hostComponents: hostComponents) }
        if let exception: PSLData = self.pslDataSet.exceptions.first(where: matchClosure) {
            return exception.parse(hostComponents: hostComponents)
        }
        if let wildcard: PSLData = self.pslDataSet.wildcards.first(where: matchClosure),
            wildcard.tldParts.count >= self.longestNormalMatch(hostComponents: hostComponents)
        {
            return wildcard.parse(hostComponents: hostComponents)
        }
        return self.parseNormals(host: host)
    }

    /// The number of labels in the longest normal rule the host matches, or 0 if none does
    private func longestNormalMatch(hostComponents: [String]) -> Int {
        for count in stride(from: hostComponents.count, to: 0, by: -1)
        where self.pslDataSet.normals.contains(hostComponents.suffix(count).joined(separator: ".")) {
            return count
        }
        return 0
    }

    internal func parseNormals(host: String) -> TLDResult? {
        let tldSet: Set<String> = self.pslDataSet.normals
        /// Split the hostname to components
        let hostComponents = host.lowercased().components(separatedBy: ".")
        /// A host must have at least two parts else it's a TLD
        guard hostComponents.count >= 2 else { return nil }
        /// Iterate from lower level domain and check if the hostname matches a suffix in the dataset
        var copiedHostComponents: ArraySlice<String> = ArraySlice(hostComponents)
        var topLevelDomain: String?
        repeat {
            guard !copiedHostComponents.isEmpty else { return nil }
            topLevelDomain = copiedHostComponents.joined(separator: ".")
            copiedHostComponents = copiedHostComponents.dropFirst()
        } while !tldSet.contains(topLevelDomain ?? "")

        if topLevelDomain == host { topLevelDomain = nil }

        /// Extract the host name to each level domain
        let rootDomainRange: Range<Int> = (copiedHostComponents.startIndex - 2)..<hostComponents.endIndex
        let rootDomain: String? = rootDomainRange.startIndex >= 0 ? hostComponents[rootDomainRange].joined(separator: ".") : nil

        let secondDomainRange: Range<Int> = (rootDomainRange.lowerBound)..<(rootDomainRange.lowerBound + 1)
        let secondDomain: String? = secondDomainRange.startIndex >= 0 ? hostComponents[secondDomainRange].joined(separator: ".") : nil

        let subDomainRange: Range<Int> = (hostComponents.startIndex)..<(max(secondDomainRange.lowerBound, hostComponents.startIndex))
        let subDomain: String? = subDomainRange.endIndex >= 1 ? hostComponents[subDomainRange].joined(separator: ".") : nil

        return TLDResult(
            rootDomain: rootDomain,
            topLevelDomain: topLevelDomain,
            secondLevelDomain: secondDomain,
            subDomain: subDomain
        )
    }
}
