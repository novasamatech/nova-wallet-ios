import XCTest
@testable import novawallet

final class CoinGeckoUrlParserTests: XCTestCase {
    func testValidUrlStrings() {
        let parser = CoingeckoUrlParser()

        XCTAssertEqual(parser.parsePriceId(from: "https://www.coingecko.com/en/coins/bitcoin"), "bitcoin")
        XCTAssertEqual(parser.parsePriceId(from: "https://www.coingecko.com/en/coins/bitcoin/"), "bitcoin")
        XCTAssertEqual(parser.parsePriceId(from: "www.coingecko.com/en/coins/bitcoin"), "bitcoin")
        XCTAssertEqual(parser.parsePriceId(from: "coingecko.com/en/coins/bitcoin"), "bitcoin")
        XCTAssertEqual(parser.parsePriceId(from: "coingecko.com/coins/bitcoin "), "bitcoin")
        XCTAssertEqual(parser.parsePriceId(from: "coingecko.com/en/coins/bitcoin?language=en"), "bitcoin")
    }

    func testInvalidUrlStrings() {
        let parser = CoingeckoUrlParser()

        XCTAssertNil(parser.parsePriceId(from: "en/coins/bitcoin"))
        XCTAssertNil(parser.parsePriceId(from: "google.com/en/coins/bitcoin/"))
        XCTAssertNil(parser.parsePriceId(from: "www.google.com/en/coins/bitcoin"))
        XCTAssertNil(parser.parsePriceId(from: "https://google.com/en/coins/bitcoin"))
    }
}
