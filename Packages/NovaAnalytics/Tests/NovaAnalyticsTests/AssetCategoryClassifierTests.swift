import XCTest
@testable import NovaAnalytics

final class AssetCategoryClassifierTests: XCTestCase {
    func testNativeTokensWinFirst() {
        XCTAssertEqual(AssetCategoryClassifier.classify("DOT"), .nativeToken)
        XCTAssertEqual(AssetCategoryClassifier.classify("KSM"), .nativeToken)
    }

    func testStablecoinsAreRecognised() {
        XCTAssertEqual(AssetCategoryClassifier.classify("USDT"), .stablecoin)
        XCTAssertEqual(AssetCategoryClassifier.classify("USDC"), .stablecoin)
    }

    func testWrappedTokensAreRecognised() {
        XCTAssertEqual(AssetCategoryClassifier.classify("WETH"), .wrappedToken)
    }

    func testWPrefixedNativeTokenIsWrappedNotNative() {
        XCTAssertEqual(AssetCategoryClassifier.classify("WDOT"), .wrappedToken)
    }

    func testUnknownSymbolFallsThroughToOther() {
        XCTAssertEqual(AssetCategoryClassifier.classify("ZZZQQQ"), .other)
    }

    func testClassificationIsCaseInsensitive() {
        XCTAssertEqual(AssetCategoryClassifier.classify("usdt"), .stablecoin)
    }
}
