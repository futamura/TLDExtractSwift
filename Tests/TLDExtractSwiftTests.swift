//
//  TLDExtractSwiftTests.swift
//  TLDExtractSwiftTests
//
//  Created by Kojiro Futamura on 2024/08/25.
//

import XCTest

@testable import TLDExtractSwift

class TLDExtractSwiftTests: XCTestCase {

    var tldExtractor: TLDExtract!

    override func setUp() {
        super.setUp()
        tldExtractor = try? TLDExtract(useFrozenData: false)
    }

    /// Runs `block` under `measure` everywhere except Linux, where it runs once untimed.
    ///
    /// Apple's XCTest reports a relative standard deviation over its 10% limit as
    /// information when no baseline is recorded, and none is here; swift-corelibs-xctest
    /// fails the test instead, and exposes no API to relax the limit. A single slow
    /// iteration on a shared runner is enough to trip it, and that already cost a week of
    /// Public Suffix List updates, because the weekly refresh workflow gates its pull
    /// request on `swift test` in a Linux container. The assertions inside these blocks
    /// are the only coverage the extraction paths get, so Linux keeps running them and
    /// gives up only the timing.
    private func measureIfSupported(_ block: () -> Void) {
        #if os(Linux)
        block()
        #else
        self.measure(block)
        #endif
    }

    /// Measures parsing rather than the network: on the SPM path `TLDExtract()` defaults
    /// to `useFrozenData: false` and downloads the list, so the ten iterations `measure`
    /// runs would time ten HTTP downloads.
    func testMeasureSetupTime() {
        measureIfSupported {
            _ = try? TLDExtract(useFrozenData: true)
        }
    }

    func testPSLParser() {
        XCTAssertNoThrow(try TLDExtract())
        XCTAssertThrowsError(try PSLParser().parse(data: Data()))
        XCTAssertThrowsError(try PSLParser().parse(data: nil))
    }

    func testPSLPriority() {
        let exception0: PSLData = PSLData(raw: "!city.yokohama.jp")
        let exception1: PSLData = PSLData(raw: "!www.ck")
        let wildcard0: PSLData = PSLData(raw: "*.yokohama.jp")
        let wildcard1: PSLData = PSLData(raw: "*.ck")

        XCTAssertTrue(exception0 > exception1)
        XCTAssertTrue(exception0 >= exception1)
        XCTAssertFalse(exception0 < exception1)
        XCTAssertFalse(exception0 <= exception1)

        XCTAssertTrue(exception0 == exception0)
        XCTAssertTrue(exception1 == exception1)

        XCTAssertTrue(wildcard0 == wildcard0)
        XCTAssertTrue(wildcard1 == wildcard1)

        XCTAssertFalse(wildcard0 == wildcard1)

        XCTAssertFalse(exception0 == exception1)

        XCTAssertFalse(exception0 == wildcard0)
        XCTAssertFalse(exception0 == wildcard1)

        XCTAssertFalse(exception1 == wildcard0)
        XCTAssertFalse(exception1 == wildcard1)
    }

    func testMeasureExtractable() {
        measureIfSupported {
            testExtractableURL()
            testExtractableString()
        }
    }

    func testMeasureParser() {
        measureIfSupported {
            testTLDExtractString(quick: false)
        }
    }

    func testMeasureParserQuick() {
        measureIfSupported {
            testTLDExtractString(quick: true)
        }
    }

    /// Test TLDExtractable.

    func testExtractableString(file: StaticString = #file, line: UInt = #line) {
        /// URL
        checkTLDExtractable("http://example.com", "example.com")
        checkTLDExtractable("https://example.com", "example.com")

        checkTLDExtractable("http://www.example.com", "www.example.com")
        checkTLDExtractable("https://www.example.com", "www.example.com")

        checkTLDExtractable("http://www.example.com/", "www.example.com")
        checkTLDExtractable("https://www.example.com/", "www.example.com")

        checkTLDExtractable("http://example.com/a/b/", "example.com")
        checkTLDExtractable("http://example.com/a/b/index.html", "example.com")

        /// URL without scheme
        checkTLDExtractable("//example.com", "example.com")
        checkTLDExtractable("//example.com/a/b/", "example.com")
        checkTLDExtractable("//example.com/a/b/index.html", "example.com")

        /// URL with localhost
        checkTLDExtractable("http://localhost", "localhost")
        checkTLDExtractable("//localhost", "localhost")
        checkTLDExtractable("localhost", "localhost")

        /// Only URL scheme
        checkTLDExtractable("http", "http")
        checkTLDExtractable("http:", nil)
        checkTLDExtractable("http://", nil)

        /// Only TLD
        checkTLDExtractable("com", "com")

        /// Hostname only
        checkTLDExtractable("example.com", "example.com")
        checkTLDExtractable("www.example.com", "www.example.com")

        /// IDNA
        checkTLDExtractable("表参道.青山.ファッション", "表参道.青山.ファッション")
        checkTLDExtractable("//表参道.青山.ファッション", "表参道.青山.ファッション")
        checkTLDExtractable("http://表参道.青山.ファッション", "表参道.青山.ファッション")
        checkTLDExtractable("http://表参道.青山.ファッション/横浜/ヤンキー/", "表参道.青山.ファッション")
        checkTLDExtractable("青山.ファッション/川崎/チンピラ/", "青山.ファッション")
        checkTLDExtractable("ファッション/埼玉/ダサイタマ/", "ファッション")
        /// Same as above, but punycoded
        checkTLDExtractable("xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c", "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable("//xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c", "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable("http://xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c", "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable("http://xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c/xn--4cw21e/xn--nckyfvbwb/", "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable("xn--rht138k.xn--bck1b9a5dre4c/xn--8ltrs/xn--7ckvb7cub/", "xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable("xn--bck1b9a5dre4c/xn--5js045d/xn--eck7a5ab7m/", "xn--bck1b9a5dre4c")

        /// IDNA - All language
        checkTLDExtractable("http://افغانستا.museum", "افغانستا.museum")
        checkTLDExtractable("http://الجزائر.museum", "الجزائر.museum")
        checkTLDExtractable("http://österreich.museum", "österreich.museum")
        checkTLDExtractable("http://বাংলাদেশ.museum", "বাংলাদেশ.museum")
        checkTLDExtractable("http://беларусь.museum", "беларусь.museum")
        checkTLDExtractable("http://belgië.museum", "belgië.museum")
        checkTLDExtractable("http://българия.museum", "българия.museum")
        checkTLDExtractable("http://تشادر.museum", "تشادر.museum")
        checkTLDExtractable("http://中国.museum", "中国.museum")
        checkTLDExtractable("http://القمر.museum", "القمر.museum")
        checkTLDExtractable("http://κυπρος.museum", "κυπρος.museum")
        checkTLDExtractable("http://českárepublika.museum", "českárepublika.museum")
        checkTLDExtractable("http://مصر.museum", "مصر.museum")
        checkTLDExtractable("http://ελλάδα.museum", "ελλάδα.museum")
        checkTLDExtractable("http://magyarország.museum", "magyarország.museum")
        checkTLDExtractable("http://ísland.museum", "ísland.museum")
        checkTLDExtractable("http://भारत.museum", "भारत.museum")
        checkTLDExtractable("http://ايران.museum", "ايران.museum")
        checkTLDExtractable("http://éire.museum", "éire.museum")
        checkTLDExtractable("http://איקו״ם.ישראל.museum", "איקו״ם.ישראל.museum")
        checkTLDExtractable("http://日本.museum", "日本.museum")
        checkTLDExtractable("http://الأردن.museum", "الأردن.museum")
        checkTLDExtractable("http://қазақстан.museum", "қазақстан.museum")
        checkTLDExtractable("http://한국.museum", "한국.museum")
        checkTLDExtractable("http://кыргызстан.museum", "кыргызстан.museum")
        checkTLDExtractable("http://ລາວ.museum", "ລາວ.museum")
        checkTLDExtractable("http://لبنان.museum", "لبنان.museum")
        checkTLDExtractable("http://македонија.museum", "македонија.museum")
        checkTLDExtractable("http://موريتانيا.museum", "موريتانيا.museum")
        checkTLDExtractable("http://méxico.museum", "méxico.museum")
        checkTLDExtractable("http://монголулс.museum", "монголулс.museum")
        checkTLDExtractable("http://المغرب.museum", "المغرب.museum")
        checkTLDExtractable("http://नेपाल.museum", "नेपाल.museum")
        checkTLDExtractable("http://عمان.museum", "عمان.museum")
        checkTLDExtractable("http://قطر.museum", "قطر.museum")
        checkTLDExtractable("http://românia.museum", "românia.museum")
        checkTLDExtractable("http://россия.иком.museum", "россия.иком.museum")
        checkTLDExtractable("http://србијаицрнагора.иком.museum", "србијаицрнагора.иком.museum")
        checkTLDExtractable("http://இலங்கை.museum", "இலங்கை.museum")
        checkTLDExtractable("http://españa.museum", "españa.museum")
        checkTLDExtractable("http://ไทย.museum", "ไทย.museum")
        checkTLDExtractable("http://تونس.museum", "تونس.museum")
        checkTLDExtractable("http://türkiye.museum", "türkiye.museum")
        checkTLDExtractable("http://украина.museum", "украина.museum")
        checkTLDExtractable("http://việtnam.museum", "việtnam.museum")
        /// Same as above, but punycoded
        checkTLDExtractable("http://xn--mgbaal8b0b9b2b.museum/", "xn--mgbaal8b0b9b2b.museum")
        checkTLDExtractable("http://xn--lgbbat1ad8j.museum/", "xn--lgbbat1ad8j.museum")
        checkTLDExtractable("http://xn--sterreich-z7a.museum/", "xn--sterreich-z7a.museum")
        checkTLDExtractable("http://xn--54b6eqazv8bc7e.museum/", "xn--54b6eqazv8bc7e.museum")
        checkTLDExtractable("http://xn--80abmy0agn7e.museum/", "xn--80abmy0agn7e.museum")
        checkTLDExtractable("http://xn--belgi-rsa.museum/", "xn--belgi-rsa.museum")
        checkTLDExtractable("http://xn--80abgvm6a7d2b.museum/", "xn--80abgvm6a7d2b.museum")
        checkTLDExtractable("http://xn--mgbfqim.museum/", "xn--mgbfqim.museum")
        checkTLDExtractable("http://xn--fiqs8s.museum/", "xn--fiqs8s.museum")
        checkTLDExtractable("http://xn--mgbu4chg.museum/", "xn--mgbu4chg.museum")
        checkTLDExtractable("http://xn--vxakceli.museum/", "xn--vxakceli.museum")
        checkTLDExtractable("http://xn--eskrepublika-ebb62d.museum/", "xn--eskrepublika-ebb62d.museum")
        checkTLDExtractable("http://xn--wgbh1c.museum/", "xn--wgbh1c.museum")
        checkTLDExtractable("http://xn--hxakic4aa.museum/", "xn--hxakic4aa.museum")
        checkTLDExtractable("http://xn--magyarorszg-t7a.museum/", "xn--magyarorszg-t7a.museum")
        checkTLDExtractable("http://xn--sland-ysa.museum/", "xn--sland-ysa.museum")
        checkTLDExtractable("http://xn--h2brj9c.museum/", "xn--h2brj9c.museum")
        checkTLDExtractable("http://xn--mgba3a4fra.museum/", "xn--mgba3a4fra.museum")
        checkTLDExtractable("http://xn--ire-9la.museum/", "xn--ire-9la.museum")
        checkTLDExtractable("http://xn--4dbklr2c8d.xn--4dbrk0ce.museum/", "xn--4dbklr2c8d.xn--4dbrk0ce.museum")
        checkTLDExtractable("http://xn--wgv71a.museum/", "xn--wgv71a.museum")
        checkTLDExtractable("http://xn--igbhzh7gpa.museum/", "xn--igbhzh7gpa.museum")
        checkTLDExtractable("http://xn--80aaa0a6awh12ed.museum/", "xn--80aaa0a6awh12ed.museum")
        checkTLDExtractable("http://xn--3e0b707e.museum/", "xn--3e0b707e.museum")
        checkTLDExtractable("http://xn--80afmksoji0fc.museum/", "xn--80afmksoji0fc.museum")
        checkTLDExtractable("http://xn--q7ce6a.museum/", "xn--q7ce6a.museum")
        checkTLDExtractable("http://xn--mgbb7fjb.museum/", "xn--mgbb7fjb.museum")
        checkTLDExtractable("http://xn--80aaldqjmmi6x.museum/", "xn--80aaldqjmmi6x.museum")
        checkTLDExtractable("http://xn--mgbah1a3hjkrd.museum/", "xn--mgbah1a3hjkrd.museum")
        checkTLDExtractable("http://xn--mxico-bsa.museum/", "xn--mxico-bsa.museum")
        checkTLDExtractable("http://xn--c1aqabffc0aq.museum/", "xn--c1aqabffc0aq.museum")
        checkTLDExtractable("http://xn--mgbc0a9azcg.museum/", "xn--mgbc0a9azcg.museum")
        checkTLDExtractable("http://xn--l2bey1c2b.museum/", "xn--l2bey1c2b.museum")
        checkTLDExtractable("http://xn--mgb9awbf.museum/", "xn--mgb9awbf.museum")
        checkTLDExtractable("http://xn--wgbl6a.museum/", "xn--wgbl6a.museum")
        checkTLDExtractable("http://xn--romnia-yta.museum/", "xn--romnia-yta.museum")
        checkTLDExtractable("http://xn--h1alffa9f.xn--h1aegh.museum/", "xn--h1alffa9f.xn--h1aegh.museum")
        checkTLDExtractable("http://xn--80aaabm1ab4blmeec9e7n.xn--h1aegh.museum/", "xn--80aaabm1ab4blmeec9e7n.xn--h1aegh.museum")
        checkTLDExtractable("http://xn--xkc2al3hye2a.museum/", "xn--xkc2al3hye2a.museum")
        checkTLDExtractable("http://xn--espaa-rta.museum/", "xn--espaa-rta.museum")
        checkTLDExtractable("http://xn--o3cw4h.museum/", "xn--o3cw4h.museum")
        checkTLDExtractable("http://xn--pgbs0dh.museum/", "xn--pgbs0dh.museum")
        checkTLDExtractable("http://xn--trkiye-3ya.museum/", "xn--trkiye-3ya.museum")
        checkTLDExtractable("http://xn--80aaxgrpt.museum/", "xn--80aaxgrpt.museum")
        checkTLDExtractable("http://xn--vitnam-jk8b.museum/", "xn--vitnam-jk8b.museum")
    }

    func testExtractableURL(file: StaticString = #file, line: UInt = #line) {
        /// URL
        checkTLDExtractable(URL(string: "http://example.com"), "example.com")
        checkTLDExtractable(URL(string: "https://example.com"), "example.com")

        checkTLDExtractable(URL(string: "http://www.example.com"), "www.example.com")
        checkTLDExtractable(URL(string: "https://www.example.com"), "www.example.com")

        checkTLDExtractable(URL(string: "http://example.com/a/b/"), "example.com")
        checkTLDExtractable(URL(string: "http://example.com/a/b/index.html"), "example.com")

        /// URL without scheme
        checkTLDExtractable(URL(string: "//example.com"), "example.com")
        checkTLDExtractable(URL(string: "//example.com/a/b/"), "example.com")
        checkTLDExtractable(URL(string: "//example.com/a/b/index.html"), "example.com")

        /// URL with localhost
        checkTLDExtractable(URL(string: "http://localhost"), "localhost")
        checkTLDExtractable(URL(string: "//localhost"), "localhost")
        checkTLDExtractable(URL(string: "localhost"), "localhost")

        /// Only URL scheme
        checkTLDExtractable(URL(string: "http"), "http")
        checkTLDExtractable(URL(string: "http:"), nil)
        checkTLDExtractable(URL(string: "http://"), nil)

        /// Only TLD
        checkTLDExtractable(URL(string: "com"), "com")

        /// Hostname only
        checkTLDExtractable(URL(string: "example.com"), "example.com")
        checkTLDExtractable(URL(string: "www.example.com"), "www.example.com")

        /// IDNA
        checkTLDExtractable(URL(unicodeString: "表参道.青山.ファッション"), "表参道.青山.ファッション")
        checkTLDExtractable(URL(unicodeString: "//表参道.青山.ファッション"), "表参道.青山.ファッション")
        checkTLDExtractable(URL(unicodeString: "http://表参道.青山.ファッション"), "表参道.青山.ファッション")
        checkTLDExtractable(URL(unicodeString: "http://表参道.青山.ファッション/横浜/ヤンキー/"), "表参道.青山.ファッション")
        checkTLDExtractable(URL(unicodeString: "青山.ファッション/川崎/チンピラ/"), "青山.ファッション")
        checkTLDExtractable(URL(unicodeString: "ファッション/埼玉/ダサイタマ/"), "ファッション")
        /// Same as above, but punycoded
        checkTLDExtractable(URL(string: "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c"), "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable(URL(string: "//xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c"), "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable(URL(string: "http://xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c"), "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable(URL(string: "http://xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c/xn--4cw21e/xn--nckyfvbwb/"), "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable(URL(string: "xn--rht138k.xn--bck1b9a5dre4c/xn--8ltrs/xn--7ckvb7cub/"), "xn--rht138k.xn--bck1b9a5dre4c")
        checkTLDExtractable(URL(string: "xn--bck1b9a5dre4c/xn--5js045d/xn--eck7a5ab7m/"), "xn--bck1b9a5dre4c")

        /// IDNA - All language
        checkTLDExtractable(URL(unicodeString: "http://افغانستا.museum"), "افغانستا.museum")
        checkTLDExtractable(URL(unicodeString: "http://الجزائر.museum"), "الجزائر.museum")
        checkTLDExtractable(URL(unicodeString: "http://österreich.museum"), "österreich.museum")
        checkTLDExtractable(URL(unicodeString: "http://বাংলাদেশ.museum"), "বাংলাদেশ.museum")
        checkTLDExtractable(URL(unicodeString: "http://беларусь.museum"), "беларусь.museum")
        checkTLDExtractable(URL(unicodeString: "http://belgië.museum"), "belgië.museum")
        checkTLDExtractable(URL(unicodeString: "http://българия.museum"), "българия.museum")
        checkTLDExtractable(URL(unicodeString: "http://تشادر.museum"), "تشادر.museum")
        checkTLDExtractable(URL(unicodeString: "http://中国.museum"), "中国.museum")
        checkTLDExtractable(URL(unicodeString: "http://القمر.museum"), "القمر.museum")
        checkTLDExtractable(URL(unicodeString: "http://κυπρος.museum"), "κυπρος.museum")
        checkTLDExtractable(URL(unicodeString: "http://českárepublika.museum"), "českárepublika.museum")
        checkTLDExtractable(URL(unicodeString: "http://مصر.museum"), "مصر.museum")
        checkTLDExtractable(URL(unicodeString: "http://ελλάδα.museum"), "ελλάδα.museum")
        checkTLDExtractable(URL(unicodeString: "http://magyarország.museum"), "magyarország.museum")
        checkTLDExtractable(URL(unicodeString: "http://ísland.museum"), "ísland.museum")
        checkTLDExtractable(URL(unicodeString: "http://भारत.museum"), "भारत.museum")
        checkTLDExtractable(URL(unicodeString: "http://ايران.museum"), "ايران.museum")
        checkTLDExtractable(URL(unicodeString: "http://éire.museum"), "éire.museum")
        checkTLDExtractable(URL(unicodeString: "http://איקו״ם.ישראל.museum"), "איקו״ם.ישראל.museum")
        checkTLDExtractable(URL(unicodeString: "http://日本.museum"), "日本.museum")
        checkTLDExtractable(URL(unicodeString: "http://الأردن.museum"), "الأردن.museum")
        checkTLDExtractable(URL(unicodeString: "http://қазақстан.museum"), "қазақстан.museum")
        checkTLDExtractable(URL(unicodeString: "http://한국.museum"), "한국.museum")
        checkTLDExtractable(URL(unicodeString: "http://кыргызстан.museum"), "кыргызстан.museum")
        checkTLDExtractable(URL(unicodeString: "http://ລາວ.museum"), "ລາວ.museum")
        checkTLDExtractable(URL(unicodeString: "http://لبنان.museum"), "لبنان.museum")
        checkTLDExtractable(URL(unicodeString: "http://македонија.museum"), "македонија.museum")
        checkTLDExtractable(URL(unicodeString: "http://موريتانيا.museum"), "موريتانيا.museum")
        checkTLDExtractable(URL(unicodeString: "http://méxico.museum"), "méxico.museum")
        checkTLDExtractable(URL(unicodeString: "http://монголулс.museum"), "монголулс.museum")
        checkTLDExtractable(URL(unicodeString: "http://المغرب.museum"), "المغرب.museum")
        checkTLDExtractable(URL(unicodeString: "http://नेपाल.museum"), "नेपाल.museum")
        checkTLDExtractable(URL(unicodeString: "http://عمان.museum"), "عمان.museum")
        checkTLDExtractable(URL(unicodeString: "http://قطر.museum"), "قطر.museum")
        checkTLDExtractable(URL(unicodeString: "http://românia.museum"), "românia.museum")
        checkTLDExtractable(URL(unicodeString: "http://россия.иком.museum"), "россия.иком.museum")
        checkTLDExtractable(URL(unicodeString: "http://србијаицрнагора.иком.museum"), "србијаицрнагора.иком.museum")
        checkTLDExtractable(URL(unicodeString: "http://இலங்கை.museum"), "இலங்கை.museum")
        checkTLDExtractable(URL(unicodeString: "http://españa.museum"), "españa.museum")
        checkTLDExtractable(URL(unicodeString: "http://ไทย.museum"), "ไทย.museum")
        checkTLDExtractable(URL(unicodeString: "http://تونس.museum"), "تونس.museum")
        checkTLDExtractable(URL(unicodeString: "http://türkiye.museum"), "türkiye.museum")
        checkTLDExtractable(URL(unicodeString: "http://украина.museum"), "украина.museum")
        checkTLDExtractable(URL(unicodeString: "http://việtnam.museum"), "việtnam.museum")
        /// Same as above, but punycoded
        checkTLDExtractable(URL(string: "http://xn--mgbaal8b0b9b2b.museum/"), "xn--mgbaal8b0b9b2b.museum")
        checkTLDExtractable(URL(string: "http://xn--lgbbat1ad8j.museum/"), "xn--lgbbat1ad8j.museum")
        checkTLDExtractable(URL(string: "http://xn--sterreich-z7a.museum/"), "xn--sterreich-z7a.museum")
        checkTLDExtractable(URL(string: "http://xn--54b6eqazv8bc7e.museum/"), "xn--54b6eqazv8bc7e.museum")
        checkTLDExtractable(URL(string: "http://xn--80abmy0agn7e.museum/"), "xn--80abmy0agn7e.museum")
        checkTLDExtractable(URL(string: "http://xn--belgi-rsa.museum/"), "xn--belgi-rsa.museum")
        checkTLDExtractable(URL(string: "http://xn--80abgvm6a7d2b.museum/"), "xn--80abgvm6a7d2b.museum")
        checkTLDExtractable(URL(string: "http://xn--mgbfqim.museum/"), "xn--mgbfqim.museum")
        checkTLDExtractable(URL(string: "http://xn--fiqs8s.museum/"), "xn--fiqs8s.museum")
        checkTLDExtractable(URL(string: "http://xn--mgbu4chg.museum/"), "xn--mgbu4chg.museum")
        checkTLDExtractable(URL(string: "http://xn--vxakceli.museum/"), "xn--vxakceli.museum")
        checkTLDExtractable(URL(string: "http://xn--eskrepublika-ebb62d.museum/"), "xn--eskrepublika-ebb62d.museum")
        checkTLDExtractable(URL(string: "http://xn--wgbh1c.museum/"), "xn--wgbh1c.museum")
        checkTLDExtractable(URL(string: "http://xn--hxakic4aa.museum/"), "xn--hxakic4aa.museum")
        checkTLDExtractable(URL(string: "http://xn--magyarorszg-t7a.museum/"), "xn--magyarorszg-t7a.museum")
        checkTLDExtractable(URL(string: "http://xn--sland-ysa.museum/"), "xn--sland-ysa.museum")
        checkTLDExtractable(URL(string: "http://xn--h2brj9c.museum/"), "xn--h2brj9c.museum")
        checkTLDExtractable(URL(string: "http://xn--mgba3a4fra.museum/"), "xn--mgba3a4fra.museum")
        checkTLDExtractable(URL(string: "http://xn--ire-9la.museum/"), "xn--ire-9la.museum")
        checkTLDExtractable(URL(string: "http://xn--4dbklr2c8d.xn--4dbrk0ce.museum/"), "xn--4dbklr2c8d.xn--4dbrk0ce.museum")
        checkTLDExtractable(URL(string: "http://xn--wgv71a.museum/"), "xn--wgv71a.museum")
        checkTLDExtractable(URL(string: "http://xn--igbhzh7gpa.museum/"), "xn--igbhzh7gpa.museum")
        checkTLDExtractable(URL(string: "http://xn--80aaa0a6awh12ed.museum/"), "xn--80aaa0a6awh12ed.museum")
        checkTLDExtractable(URL(string: "http://xn--3e0b707e.museum/"), "xn--3e0b707e.museum")
        checkTLDExtractable(URL(string: "http://xn--80afmksoji0fc.museum/"), "xn--80afmksoji0fc.museum")
        checkTLDExtractable(URL(string: "http://xn--q7ce6a.museum/"), "xn--q7ce6a.museum")
        checkTLDExtractable(URL(string: "http://xn--mgbb7fjb.museum/"), "xn--mgbb7fjb.museum")
        checkTLDExtractable(URL(string: "http://xn--80aaldqjmmi6x.museum/"), "xn--80aaldqjmmi6x.museum")
        checkTLDExtractable(URL(string: "http://xn--mgbah1a3hjkrd.museum/"), "xn--mgbah1a3hjkrd.museum")
        checkTLDExtractable(URL(string: "http://xn--mxico-bsa.museum/"), "xn--mxico-bsa.museum")
        checkTLDExtractable(URL(string: "http://xn--c1aqabffc0aq.museum/"), "xn--c1aqabffc0aq.museum")
        checkTLDExtractable(URL(string: "http://xn--mgbc0a9azcg.museum/"), "xn--mgbc0a9azcg.museum")
        checkTLDExtractable(URL(string: "http://xn--l2bey1c2b.museum/"), "xn--l2bey1c2b.museum")
        checkTLDExtractable(URL(string: "http://xn--mgb9awbf.museum/"), "xn--mgb9awbf.museum")
        checkTLDExtractable(URL(string: "http://xn--wgbl6a.museum/"), "xn--wgbl6a.museum")
        checkTLDExtractable(URL(string: "http://xn--romnia-yta.museum/"), "xn--romnia-yta.museum")
        checkTLDExtractable(URL(string: "http://xn--h1alffa9f.xn--h1aegh.museum/"), "xn--h1alffa9f.xn--h1aegh.museum")
        checkTLDExtractable(URL(string: "http://xn--80aaabm1ab4blmeec9e7n.xn--h1aegh.museum/"), "xn--80aaabm1ab4blmeec9e7n.xn--h1aegh.museum")
        checkTLDExtractable(URL(string: "http://xn--xkc2al3hye2a.museum/"), "xn--xkc2al3hye2a.museum")
        checkTLDExtractable(URL(string: "http://xn--espaa-rta.museum/"), "xn--espaa-rta.museum")
        checkTLDExtractable(URL(string: "http://xn--o3cw4h.museum/"), "xn--o3cw4h.museum")
        checkTLDExtractable(URL(string: "http://xn--pgbs0dh.museum/"), "xn--pgbs0dh.museum")
        checkTLDExtractable(URL(string: "http://xn--trkiye-3ya.museum/"), "xn--trkiye-3ya.museum")
        checkTLDExtractable(URL(string: "http://xn--80aaxgrpt.museum/"), "xn--80aaxgrpt.museum")
        checkTLDExtractable(URL(string: "http://xn--vitnam-jk8b.museum/"), "xn--vitnam-jk8b.museum")
    }

    /// Common PSL Unit Test case.
    /// Source: https://raw.githubusercontent.com/publicsuffix/list/master/tests/test_psl.txt
    func testTLDExtractString(quick: Bool) {
        NSLog("Quick option is \(quick ? "enabled" : "disabled").")

        /// nil input.
        let val: String? = nil
        checkPublicSuffix(val, nil, nil, nil, nil, quick: quick)

        /// Mixed case.
        checkPublicSuffix("COM", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("example.COM", "example.com", "com", "example", nil, quick: quick)
        checkPublicSuffix("WwW.example.COM", "example.com", "com", "example", "www", quick: quick)

        /// Leading dot.
        /// Listed, but non - Internet, TLD.
        checkPublicSuffix("local", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("example.local", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("b.example.local", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("a.b.example.local", nil, nil, nil, nil, quick: quick)

        /// TLD with only 1 rule.
        checkPublicSuffix("biz", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("domain.biz", "domain.biz", "biz", "domain", nil, quick: quick)
        checkPublicSuffix("b.domain.biz", "domain.biz", "biz", "domain", "b", quick: quick)
        checkPublicSuffix("a.b.domain.biz", "domain.biz", "biz", "domain", "a.b", quick: quick)

        /// TLD with some 2-level rules.
        checkPublicSuffix("com", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("example.com", "example.com", "com", "example", nil, quick: quick)
        checkPublicSuffix("b.example.com", "example.com", "com", "example", "b", quick: quick)
        checkPublicSuffix("a.b.example.com", "example.com", "com", "example", "a.b", quick: quick)
        checkPublicSuffix("uk.com", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("example.uk.com", "example.uk.com", "uk.com", "example", nil, quick: quick)
        checkPublicSuffix("b.example.uk.com", "example.uk.com", "uk.com", "example", "b", quick: quick)
        checkPublicSuffix("a.b.example.uk.com", "example.uk.com", "uk.com", "example", "a.b", quick: quick)
        checkPublicSuffix("test.ac", "test.ac", "ac", "test", nil, quick: quick)

        /// TLD with only 1 (wildcard, quick: quick) rule.
        checkPublicSuffix("mm", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("c.mm", nil, nil, nil, nil, quick: quick)
        if quick {
            /// Wildcards and exception data with quick option always returns nil
            checkPublicSuffix("b.c.mm", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("a.b.c.mm", nil, nil, nil, nil, quick: quick)
        } else {
            checkPublicSuffix("b.c.mm", "b.c.mm", "c.mm", "b", nil, quick: quick)
            checkPublicSuffix("a.b.c.mm", "b.c.mm", "c.mm", "b", "a", quick: quick)
        }

        /// More complex TLD.
        checkPublicSuffix("jp", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("test.jp", "test.jp", "jp", "test", nil, quick: quick)
        checkPublicSuffix("www.test.jp", "test.jp", "jp", "test", "www", quick: quick)
        checkPublicSuffix("ac.jp", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("test.ac.jp", "test.ac.jp", "ac.jp", "test", nil, quick: quick)
        checkPublicSuffix("www.test.ac.jp", "test.ac.jp", "ac.jp", "test", "www", quick: quick)
        checkPublicSuffix("kyoto.jp", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("test.kyoto.jp", "test.kyoto.jp", "kyoto.jp", "test", nil, quick: quick)
        checkPublicSuffix("ide.kyoto.jp", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("b.ide.kyoto.jp", "b.ide.kyoto.jp", "ide.kyoto.jp", "b", nil, quick: quick)
        checkPublicSuffix("a.b.ide.kyoto.jp", "b.ide.kyoto.jp", "ide.kyoto.jp", "b", "a", quick: quick)
        if quick {
            /// The results of wildcards and exceptions depend on the quick option
            checkPublicSuffix("c.kobe.jp", "kobe.jp", "jp", "kobe", "c", quick: quick)
            checkPublicSuffix("b.c.kobe.jp", "kobe.jp", "jp", "kobe", "b.c", quick: quick)
            checkPublicSuffix("a.b.c.kobe.jp", "kobe.jp", "jp", "kobe", "a.b.c", quick: quick)
            checkPublicSuffix("city.kobe.jp", "kobe.jp", "jp", "kobe", "city", quick: quick)
            checkPublicSuffix("www.city.kobe.jp", "kobe.jp", "jp", "kobe", "www.city", quick: quick)
        } else {
            checkPublicSuffix("c.kobe.jp", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("b.c.kobe.jp", "b.c.kobe.jp", "c.kobe.jp", "b", nil, quick: quick)
            checkPublicSuffix("a.b.c.kobe.jp", "b.c.kobe.jp", "c.kobe.jp", "b", "a", quick: quick)
            checkPublicSuffix("city.kobe.jp", "city.kobe.jp", "kobe.jp", "city", nil, quick: quick)
            checkPublicSuffix("www.city.kobe.jp", "city.kobe.jp", "kobe.jp", "city", "www", quick: quick)
        }

        /// TLD with a wildcard rule and exceptions.
        if quick {
            /// Wildcards and exception data with quick option always returns nil
            checkPublicSuffix("ck", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("test.ck", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("b.test.ck", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("a.b.test.ck", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("www.ck", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("www.www.ck", nil, nil, nil, nil, quick: quick)
        } else {
            checkPublicSuffix("ck", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("test.ck", nil, nil, nil, nil, quick: quick)
            checkPublicSuffix("b.test.ck", "b.test.ck", "test.ck", "b", nil, quick: quick)
            checkPublicSuffix("a.b.test.ck", "b.test.ck", "test.ck", "b", "a", quick: quick)
            checkPublicSuffix("www.ck", "www.ck", "ck", "www", nil, quick: quick)
            checkPublicSuffix("www.www.ck", "www.ck", "ck", "www", "www", quick: quick)
        }

        /// US K12.
        checkPublicSuffix("us", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("test.us", "test.us", "us", "test", nil, quick: quick)
        checkPublicSuffix("www.test.us", "test.us", "us", "test", "www", quick: quick)
        checkPublicSuffix("ak.us", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("test.ak.us", "test.ak.us", "ak.us", "test", nil, quick: quick)
        checkPublicSuffix("www.test.ak.us", "test.ak.us", "ak.us", "test", "www", quick: quick)
        checkPublicSuffix("k12.ak.us", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("test.k12.ak.us", "test.k12.ak.us", "k12.ak.us", "test", nil, quick: quick)
        checkPublicSuffix("www.test.k12.ak.us", "test.k12.ak.us", "k12.ak.us", "test", "www", quick: quick)

        /// IDN labels.
        checkPublicSuffix("食狮.com.cn", "食狮.com.cn", "com.cn", "食狮", nil, quick: quick)
        checkPublicSuffix("食狮.公司.cn", "食狮.公司.cn", "公司.cn", "食狮", nil, quick: quick)
        checkPublicSuffix("www.食狮.公司.cn", "食狮.公司.cn", "公司.cn", "食狮", "www", quick: quick)
        checkPublicSuffix("shishi.公司.cn", "shishi.公司.cn", "公司.cn", "shishi", nil, quick: quick)
        checkPublicSuffix("公司.cn", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("食狮.中国", "食狮.中国", "中国", "食狮", nil, quick: quick)
        checkPublicSuffix("www.食狮.中国", "食狮.中国", "中国", "食狮", "www", quick: quick)
        checkPublicSuffix("shishi.中国", "shishi.中国", "中国", "shishi", nil, quick: quick)
        checkPublicSuffix("中国", nil, nil, nil, nil, quick: quick)
        /// Same as above, but punycoded.
        checkPublicSuffix("xn--85x722f.com.cn", "xn--85x722f.com.cn", "com.cn", "xn--85x722f", nil, quick: quick)
        checkPublicSuffix("xn--85x722f.xn--55qx5d.cn", "xn--85x722f.xn--55qx5d.cn", "xn--55qx5d.cn", "xn--85x722f", nil, quick: quick)
        checkPublicSuffix("www.xn--85x722f.xn--55qx5d.cn", "xn--85x722f.xn--55qx5d.cn", "xn--55qx5d.cn", "xn--85x722f", "www", quick: quick)
        checkPublicSuffix("shishi.xn--55qx5d.cn", "shishi.xn--55qx5d.cn", "xn--55qx5d.cn", "shishi", nil, quick: quick)
        checkPublicSuffix("xn--55qx5d.cn", nil, nil, nil, nil, quick: quick)
        checkPublicSuffix("xn--85x722f.xn--fiqs8s", "xn--85x722f.xn--fiqs8s", "xn--fiqs8s", "xn--85x722f", nil, quick: quick)
        checkPublicSuffix("www.xn--85x722f.xn--fiqs8s", "xn--85x722f.xn--fiqs8s", "xn--fiqs8s", "xn--85x722f", "www", quick: quick)
        checkPublicSuffix("shishi.xn--fiqs8s", "shishi.xn--fiqs8s", "xn--fiqs8s", "shishi", nil, quick: quick)
        checkPublicSuffix("xn--fiqs8s", nil, nil, nil, nil, quick: quick)

        /// Japanese IDN labels.
        checkPublicSuffix("忍者.jp", "忍者.jp", "jp", "忍者", nil, quick: quick)
        checkPublicSuffix("サムライ.忍者.jp", "忍者.jp", "jp", "忍者", "サムライ", quick: quick)
        checkPublicSuffix("www.サムライ.忍者.jp", "忍者.jp", "jp", "忍者", "www.サムライ", quick: quick)
        checkPublicSuffix("ラーメン.寿司.co.jp", "寿司.co.jp", "co.jp", "寿司", "ラーメン", quick: quick)
        checkPublicSuffix("www.ラーメン.寿司.co.jp", "寿司.co.jp", "co.jp", "寿司", "www.ラーメン", quick: quick)
        checkPublicSuffix("餃子.食品", "餃子.食品", "食品", "餃子", nil, quick: quick)
        checkPublicSuffix("チャーハン.餃子.食品", "餃子.食品", "食品", "餃子", "チャーハン", quick: quick)
        checkPublicSuffix("www.チャーハン.餃子.食品", "餃子.食品", "食品", "餃子", "www.チャーハン", quick: quick)
        checkPublicSuffix("青山.ファッション", "青山.ファッション", "ファッション", "青山", nil, quick: quick)
        checkPublicSuffix("表参道.青山.ファッション", "青山.ファッション", "ファッション", "青山", "表参道", quick: quick)
        checkPublicSuffix("www.表参道.青山.ファッション", "青山.ファッション", "ファッション", "青山", "www.表参道", quick: quick)
        checkPublicSuffix("www.おしゃれ.表参道.青山.ファッション", "青山.ファッション", "ファッション", "青山", "www.おしゃれ.表参道", quick: quick)
        checkPublicSuffix("日本", nil, nil, nil, nil, quick: quick)
        /// Same as above, but punycoded.
        checkPublicSuffix("xn--c6t203e.jp", "xn--c6t203e.jp", "jp", "xn--c6t203e", nil, quick: quick)
        checkPublicSuffix("xn--eck7azimb.xn--c6t203e.jp", "xn--c6t203e.jp", "jp", "xn--c6t203e", "xn--eck7azimb", quick: quick)
        checkPublicSuffix("www.xn--eck7azimb.xn--c6t203e.jp", "xn--c6t203e.jp", "jp", "xn--c6t203e", "www.xn--eck7azimb", quick: quick)
        checkPublicSuffix("xn--4dkp5a8a.xn--sprr0q.co.jp", "xn--sprr0q.co.jp", "co.jp", "xn--sprr0q", "xn--4dkp5a8a", quick: quick)
        checkPublicSuffix("www.xn--4dkp5a8a.xn--sprr0q.co.jp", "xn--sprr0q.co.jp", "co.jp", "xn--sprr0q", "www.xn--4dkp5a8a", quick: quick)
        checkPublicSuffix("xn--i8st94l.xn--jvr189m", "xn--i8st94l.xn--jvr189m", "xn--jvr189m", "xn--i8st94l", nil, quick: quick)
        checkPublicSuffix("xn--7ck2a9c3czb.xn--i8st94l.xn--jvr189m", "xn--i8st94l.xn--jvr189m", "xn--jvr189m", "xn--i8st94l", "xn--7ck2a9c3czb", quick: quick)
        checkPublicSuffix("www.xn--7ck2a9c3czb.xn--i8st94l.xn--jvr189m", "xn--i8st94l.xn--jvr189m", "xn--jvr189m", "xn--i8st94l", "www.xn--7ck2a9c3czb", quick: quick)
        checkPublicSuffix("xn--rht138k.xn--bck1b9a5dre4c", "xn--rht138k.xn--bck1b9a5dre4c", "xn--bck1b9a5dre4c", "xn--rht138k", nil, quick: quick)
        checkPublicSuffix("xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c", "xn--rht138k.xn--bck1b9a5dre4c", "xn--bck1b9a5dre4c", "xn--rht138k", "xn--8nr183j17e", quick: quick)
        checkPublicSuffix("www.xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c", "xn--rht138k.xn--bck1b9a5dre4c", "xn--bck1b9a5dre4c", "xn--rht138k", "www.xn--8nr183j17e", quick: quick)
        checkPublicSuffix(
            "www.xn--t8j0ayjlb.xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c",
            "xn--rht138k.xn--bck1b9a5dre4c",
            "xn--bck1b9a5dre4c",
            "xn--rht138k",
            "www.xn--t8j0ayjlb.xn--8nr183j17e",
            quick: quick
        )
        checkPublicSuffix("xn--wgv71a", nil, nil, nil, nil, quick: quick)

    }

    func testTLDExtractURL(quick: Bool) {
        NSLog("Quick option is \(quick ? "enabled" : "disabled").")

        /// nil input.
        let val: URL? = nil
        checkPublicSuffix(val, nil, nil, nil, nil, quick: quick)

        /// Mixed case.
        checkPublicSuffix(URL(string: "COM"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "example.COM"), "example.com", "com", "example", nil, quick: quick)
        checkPublicSuffix(URL(string: "WwW.example.COM"), "example.com", "com", "example", "www", quick: quick)

        /// Leading dot.
        /// Listed, but non - Internet, TLD.
        checkPublicSuffix(URL(string: "local"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "example.local"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "b.example.local"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "a.b.example.local"), nil, nil, nil, nil, quick: quick)

        /// TLD with only 1 rule.
        checkPublicSuffix(URL(string: "biz"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "domain.biz"), "domain.biz", "biz", "domain", nil, quick: quick)
        checkPublicSuffix(URL(string: "b.domain.biz"), "domain.biz", "biz", "domain", "b", quick: quick)
        checkPublicSuffix(URL(string: "a.b.domain.biz"), "domain.biz", "biz", "domain", "a.b", quick: quick)

        /// TLD with some 2-level rules.
        checkPublicSuffix(URL(string: "com"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "example.com"), "example.com", "com", "example", nil, quick: quick)
        checkPublicSuffix(URL(string: "b.example.com"), "example.com", "com", "example", "b", quick: quick)
        checkPublicSuffix(URL(string: "a.b.example.com"), "example.com", "com", "example", "a.b", quick: quick)
        checkPublicSuffix(URL(string: "uk.com"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "example.uk.com"), "example.uk.com", "uk.com", "example", nil, quick: quick)
        checkPublicSuffix(URL(string: "b.example.uk.com"), "example.uk.com", "uk.com", "example", "b", quick: quick)
        checkPublicSuffix(URL(string: "a.b.example.uk.com"), "example.uk.com", "uk.com", "example", "a.b", quick: quick)
        checkPublicSuffix(URL(string: "test.ac"), "test.ac", "ac", "test", nil, quick: quick)

        /// TLD with only 1 (wildcard, quick: quick) rule.
        checkPublicSuffix(URL(string: "mm"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "c.mm"), nil, nil, nil, nil, quick: quick)
        if quick {
            /// Wildcards and exception data with quick option always returns nil
            checkPublicSuffix(URL(string: "b.c.mm"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "a.b.c.mm"), nil, nil, nil, nil, quick: quick)
        } else {
            checkPublicSuffix(URL(string: "b.c.mm"), "b.c.mm", "c.mm", "b", nil, quick: quick)
            checkPublicSuffix(URL(string: "a.b.c.mm"), "b.c.mm", "c.mm", "b", "a", quick: quick)
        }

        /// More complex TLD.
        checkPublicSuffix(URL(string: "jp"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "test.jp"), "test.jp", "jp", "test", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.test.jp"), "test.jp", "jp", "test", "www", quick: quick)
        checkPublicSuffix(URL(string: "ac.jp"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "test.ac.jp"), "test.ac.jp", "ac.jp", "test", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.test.ac.jp"), "test.ac.jp", "ac.jp", "test", "www", quick: quick)
        checkPublicSuffix(URL(string: "kyoto.jp"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "test.kyoto.jp"), "test.kyoto.jp", "kyoto.jp", "test", nil, quick: quick)
        checkPublicSuffix(URL(string: "ide.kyoto.jp"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "b.ide.kyoto.jp"), "b.ide.kyoto.jp", "ide.kyoto.jp", "b", nil, quick: quick)
        checkPublicSuffix(URL(string: "a.b.ide.kyoto.jp"), "b.ide.kyoto.jp", "ide.kyoto.jp", "b", "a", quick: quick)
        if quick {
            /// The results of wildcards and exceptions depend on the quick option
            checkPublicSuffix(URL(string: "c.kobe.jp"), "kobe.jp", "jp", "kobe", "c", quick: quick)
            checkPublicSuffix(URL(string: "b.c.kobe.jp"), "kobe.jp", "jp", "kobe", "b.c", quick: quick)
            checkPublicSuffix(URL(string: "a.b.c.kobe.jp"), "kobe.jp", "jp", "kobe", "a.b.c", quick: quick)
            checkPublicSuffix(URL(string: "city.kobe.jp"), "kobe.jp", "jp", "kobe", "city", quick: quick)
            checkPublicSuffix(URL(string: "www.city.kobe.jp"), "kobe.jp", "jp", "kobe", "www.city", quick: quick)
        } else {
            checkPublicSuffix(URL(string: "c.kobe.jp"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "b.c.kobe.jp"), "b.c.kobe.jp", "c.kobe.jp", "b", nil, quick: quick)
            checkPublicSuffix(URL(string: "a.b.c.kobe.jp"), "b.c.kobe.jp", "c.kobe.jp", "b", "a", quick: quick)
            checkPublicSuffix(URL(string: "city.kobe.jp"), "city.kobe.jp", "kobe.jp", "city", nil, quick: quick)
            checkPublicSuffix(URL(string: "www.city.kobe.jp"), "city.kobe.jp", "kobe.jp", "city", "www", quick: quick)
        }

        /// TLD with a wildcard rule and exceptions.
        if quick {
            /// Wildcards and exception data with quick option always returns nil
            checkPublicSuffix(URL(string: "ck"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "test.ck"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "b.test.ck"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "a.b.test.ck"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "www.ck"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "www.www.ck"), nil, nil, nil, nil, quick: quick)
        } else {
            checkPublicSuffix(URL(string: "ck"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "test.ck"), nil, nil, nil, nil, quick: quick)
            checkPublicSuffix(URL(string: "b.test.ck"), "b.test.ck", "test.ck", "b", nil, quick: quick)
            checkPublicSuffix(URL(string: "a.b.test.ck"), "b.test.ck", "test.ck", "b", "a", quick: quick)
            checkPublicSuffix(URL(string: "www.ck"), "www.ck", "ck", "www", nil, quick: quick)
            checkPublicSuffix(URL(string: "www.www.ck"), "www.ck", "ck", "www", "www", quick: quick)
        }

        /// US K12.
        checkPublicSuffix(URL(string: "us"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "test.us"), "test.us", "us", "test", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.test.us"), "test.us", "us", "test", "www", quick: quick)
        checkPublicSuffix(URL(string: "ak.us"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "test.ak.us"), "test.ak.us", "ak.us", "test", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.test.ak.us"), "test.ak.us", "ak.us", "test", "www", quick: quick)
        checkPublicSuffix(URL(string: "k12.ak.us"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "test.k12.ak.us"), "test.k12.ak.us", "k12.ak.us", "test", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.test.k12.ak.us"), "test.k12.ak.us", "k12.ak.us", "test", "www", quick: quick)

        /// IDN labels.
        checkPublicSuffix(URL(string: "食狮.com.cn"), "食狮.com.cn", "com.cn", "食狮", nil, quick: quick)
        checkPublicSuffix(URL(string: "食狮.公司.cn"), "食狮.公司.cn", "公司.cn", "食狮", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.食狮.公司.cn"), "食狮.公司.cn", "公司.cn", "食狮", "www", quick: quick)
        checkPublicSuffix(URL(string: "shishi.公司.cn"), "shishi.公司.cn", "公司.cn", "shishi", nil, quick: quick)
        checkPublicSuffix(URL(string: "公司.cn"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "食狮.中国"), "食狮.中国", "中国", "食狮", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.食狮.中国"), "食狮.中国", "中国", "食狮", "www", quick: quick)
        checkPublicSuffix(URL(string: "shishi.中国"), "shishi.中国", "中国", "shishi", nil, quick: quick)
        checkPublicSuffix(URL(string: "中国"), nil, nil, nil, nil, quick: quick)
        /// Same as above, but punycoded.
        checkPublicSuffix(URL(string: "xn--85x722f.com.cn"), "xn--85x722f.com.cn", "com.cn", "xn--85x722f", nil, quick: quick)
        checkPublicSuffix(URL(string: "xn--85x722f.xn--55qx5d.cn"), "xn--85x722f.xn--55qx5d.cn", "xn--55qx5d.cn", "xn--85x722f", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.xn--85x722f.xn--55qx5d.cn"), "xn--85x722f.xn--55qx5d.cn", "xn--55qx5d.cn", "xn--85x722f", "www", quick: quick)
        checkPublicSuffix(URL(string: "shishi.xn--55qx5d.cn"), "shishi.xn--55qx5d.cn", "xn--55qx5d.cn", "shishi", nil, quick: quick)
        checkPublicSuffix(URL(string: "xn--55qx5d.cn"), nil, nil, nil, nil, quick: quick)
        checkPublicSuffix(URL(string: "xn--85x722f.xn--fiqs8s"), "xn--85x722f.xn--fiqs8s", "xn--fiqs8s", "xn--85x722f", nil, quick: quick)
        checkPublicSuffix(URL(string: "www.xn--85x722f.xn--fiqs8s"), "xn--85x722f.xn--fiqs8s", "xn--fiqs8s", "xn--85x722f", "www", quick: quick)
        checkPublicSuffix(URL(string: "shishi.xn--fiqs8s"), "shishi.xn--fiqs8s", "xn--fiqs8s", "shishi", nil, quick: quick)
        checkPublicSuffix(URL(string: "xn--fiqs8s"), nil, nil, nil, nil, quick: quick)

        /// Japanese IDN labels.
        checkPublicSuffix(URL(unicodeString: "忍者.jp"), "忍者.jp", "jp", "忍者", nil, quick: quick)
        checkPublicSuffix(URL(unicodeString: "サムライ.忍者.jp"), "忍者.jp", "jp", "忍者", "サムライ", quick: quick)
        checkPublicSuffix(URL(unicodeString: "www.サムライ.忍者.jp"), "忍者.jp", "jp", "忍者", "www.サムライ", quick: quick)
        checkPublicSuffix(URL(unicodeString: "ラーメン.寿司.co.jp"), "寿司.co.jp", "co.jp", "寿司", "ラーメン", quick: quick)
        checkPublicSuffix(URL(unicodeString: "www.ラーメン.寿司.co.jp"), "寿司.co.jp", "co.jp", "寿司", "www.ラーメン", quick: quick)
        checkPublicSuffix(URL(unicodeString: "餃子.食品"), "餃子.食品", "食品", "餃子", nil, quick: quick)
        checkPublicSuffix(URL(unicodeString: "チャーハン.餃子.食品"), "餃子.食品", "食品", "餃子", "チャーハン", quick: quick)
        checkPublicSuffix(URL(unicodeString: "www.チャーハン.餃子.食品"), "餃子.食品", "食品", "餃子", "www.チャーハン", quick: quick)
        checkPublicSuffix(URL(unicodeString: "青山.ファッション"), "青山.ファッション", "ファッション", "青山", nil, quick: quick)
        checkPublicSuffix(URL(unicodeString: "表参道.青山.ファッション"), "青山.ファッション", "ファッション", "青山", "表参道", quick: quick)
        checkPublicSuffix(URL(unicodeString: "www.表参道.青山.ファッション"), "青山.ファッション", "ファッション", "青山", "www.表参道", quick: quick)
        checkPublicSuffix(URL(unicodeString: "www.おしゃれ.表参道.青山.ファッション"), "青山.ファッション", "ファッション", "青山", "www.おしゃれ.表参道", quick: quick)
        checkPublicSuffix(URL(unicodeString: "日本"), nil, nil, nil, nil, quick: quick)
        /// Same as above, but punycoded.
        checkPublicSuffix(URL(string: "xn--c6t203e.jp"), "xn--c6t203e.jp", "jp", "xn--c6t203e", nil, quick: quick)
        checkPublicSuffix(URL(string: "xn--eck7azimb.xn--c6t203e.jp"), "xn--c6t203e.jp", "jp", "xn--c6t203e", "xn--eck7azimb", quick: quick)
        checkPublicSuffix(URL(string: "www.xn--eck7azimb.xn--c6t203e.jp"), "xn--c6t203e.jp", "jp", "xn--c6t203e", "www.xn--eck7azimb", quick: quick)
        checkPublicSuffix(URL(string: "xn--4dkp5a8a.xn--sprr0q.co.jp"), "xn--sprr0q.co.jp", "co.jp", "xn--sprr0q", "xn--4dkp5a8a", quick: quick)
        checkPublicSuffix(URL(string: "www.xn--4dkp5a8a.xn--sprr0q.co.jp"), "xn--sprr0q.co.jp", "co.jp", "xn--sprr0q", "www.xn--4dkp5a8a", quick: quick)
        checkPublicSuffix(URL(string: "xn--i8st94l.xn--jvr189m"), "xn--i8st94l.xn--jvr189m", "xn--jvr189m", "xn--i8st94l", nil, quick: quick)
        checkPublicSuffix(URL(string: "xn--7ck2a9c3czb.xn--i8st94l.xn--jvr189m"), "xn--i8st94l.xn--jvr189m", "xn--jvr189m", "xn--i8st94l", "xn--7ck2a9c3czb", quick: quick)
        checkPublicSuffix(URL(string: "www.xn--7ck2a9c3czb.xn--i8st94l.xn--jvr189m"), "xn--i8st94l.xn--jvr189m", "xn--jvr189m", "xn--i8st94l", "www.xn--7ck2a9c3czb", quick: quick)
        checkPublicSuffix(URL(string: "xn--rht138k.xn--bck1b9a5dre4c"), "xn--rht138k.xn--bck1b9a5dre4c", "xn--bck1b9a5dre4c", "xn--rht138k", nil, quick: quick)
        checkPublicSuffix(URL(string: "xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c"), "xn--rht138k.xn--bck1b9a5dre4c", "xn--bck1b9a5dre4c", "xn--rht138k", "xn--8nr183j17e", quick: quick)
        checkPublicSuffix(URL(string: "www.xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c"), "xn--rht138k.xn--bck1b9a5dre4c", "xn--bck1b9a5dre4c", "xn--rht138k", "www.xn--8nr183j17e", quick: quick)
        checkPublicSuffix(
            URL(string: "www.xn--t8j0ayjlb.xn--8nr183j17e.xn--rht138k.xn--bck1b9a5dre4c"),
            "xn--rht138k.xn--bck1b9a5dre4c",
            "xn--bck1b9a5dre4c",
            "xn--rht138k",
            "www.xn--t8j0ayjlb.xn--8nr183j17e",
            quick: quick
        )
        checkPublicSuffix(URL(string: "xn--wgv71a"), nil, nil, nil, nil, quick: quick)
    }

    func checkTLDExtractable<T: TLDExtractable>(
        _ input: T?,
        _ expected: String?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let result: String? = input?.hostname

        //        logTLDExtractable(input, result, expected)

        XCTAssertEqual(result, expected, file: file, line: line)
    }

    func checkPublicSuffix<T: TLDExtractable>(
        _ input: T?,
        _ expectedRootDomain: String?,
        _ expectedTopLevelDomain: String?,
        _ expectedSecondDomain: String?,
        _ expectedSubDomain: String?,
        quick: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let input: T = input else { return }
        let result: TLDResult? = tldExtractor.parse(input, quick: quick)

        //        logTLDResult(host, expectedRootDomain, expectedTopLevelDomain, expectedSecondDomain, expectedSubDomain, result)

        XCTAssertEqual(result?.rootDomain, expectedRootDomain, file: file, line: line)
        XCTAssertEqual(result?.topLevelDomain, expectedTopLevelDomain, file: file, line: line)
        XCTAssertEqual(result?.secondLevelDomain, expectedSecondDomain, file: file, line: line)
        XCTAssertEqual(result?.subDomain, expectedSubDomain, file: file, line: line)
    }

    /// For debugging
    func logTLDExtractable(
        _ input: TLDExtractable?,
        _ result: String?,
        _ expected: String?
    ) {

        print("----------------------------")
        print("input:            \(input ?? "nil")")
        print("result:           \(result ?? "nil")")
        print("expected:         \(expected ?? "nil")")
        print("")
    }

    func logTLDResult(
        _ host: String?,
        _ expectedRootDomain: String?,
        _ expectedTopLevelDomain: String?,
        _ expectedSecondDomain: String?,
        _ expectedSubDomain: String?,
        _ result: TLDResult?
    ) {
        guard let host = host else { return }
        let hostStr: String = host.padding(toLength: 20, withPad: " ", startingAt: 0)

        let expectedRootStr: String = "\(expectedRootDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)
        let expectedTopStr: String = "\(expectedTopLevelDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)
        let expectedSecondStr: String = "\(expectedSecondDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)
        let expectedSubStr: String = "\(expectedSubDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)

        let resultRootStr: String = "\(result?.rootDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)
        let resultTopStr: String = "\(result?.topLevelDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)
        let resultSecondStr: String = "\(result?.secondLevelDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)
        let resultSubStr: String = "\(result?.subDomain ?? "nil")".padding(toLength: 20, withPad: " ", startingAt: 0)

        print("----------------------------")
        print("hostStr:             \(hostStr)")
        print("Root domain:         \(expectedRootStr) => \(resultRootStr)")
        print("Top level domain:    \(expectedTopStr) => \(resultTopStr)")
        print("Second level domain: \(expectedSecondStr) => \(resultSecondStr)")
        print("Sub domain:          \(expectedSubStr) => \(resultSubStr)")
    }
}
