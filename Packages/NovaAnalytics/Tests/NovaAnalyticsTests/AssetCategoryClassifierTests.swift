import XCTest
@testable import NovaAnalytics

final class AssetCategoryClassifierTests: XCTestCase {
    func testClassifiesKnownSymbols() {
        XCTAssertEqual(AssetCategoryClassifier.classify("DOT"), .nativeToken)
        XCTAssertEqual(AssetCategoryClassifier.classify("KSM"), .nativeToken)
        XCTAssertEqual(AssetCategoryClassifier.classify("USDT"), .stablecoin)
        XCTAssertEqual(AssetCategoryClassifier.classify("USDC"), .stablecoin)
        XCTAssertEqual(AssetCategoryClassifier.classify("WETH"), .wrappedToken)
    }

    func testUnknownSymbolIsOther() {
        XCTAssertEqual(AssetCategoryClassifier.classify("ZZZQQQ"), .other)
    }
}
