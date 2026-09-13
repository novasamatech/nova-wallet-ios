import XCTest
@testable import novawallet

final class AssetVisibilityTests: XCTestCase {
    private let curated = ChainAssetId(chainId: KnowChainId.polkadot, assetId: 0)
    private let uncurated = ChainAssetId(chainId: KnowChainId.polkadot, assetId: 7)
    private let filtered = ChainAssetId(chainId: KnowChainId.polkadot, assetId: 9)

    func testResolutionTable() {
        // given

        let curatedList = DefaultAssetsList(ids: [curated])

        // when

        let shown = AssetVisibility(
            defaults: curatedList,
            rows: [curated: .visible, uncurated: .visible]
        )

        let hidden = AssetVisibility(
            defaults: curatedList,
            rows: [curated: .hidden, uncurated: .hidden]
        )

        let hiddenUntilBalance = AssetVisibility(
            defaults: curatedList,
            rows: [curated: .hiddenUntilBalance, uncurated: .hiddenUntilBalance]
        )

        let undecided = AssetVisibility(defaults: curatedList, rows: [:])

        let fallback = AssetVisibility(
            defaults: .empty,
            rows: [curated: .visible, uncurated: .hidden, filtered: .hiddenUntilBalance]
        )

        let fallbackUndecided = AssetVisibility(defaults: .empty, rows: [:])

        // then

        XCTAssertTrue(shown.isVisible(curated))
        XCTAssertTrue(shown.isVisible(uncurated))

        XCTAssertFalse(hidden.isVisible(curated))
        XCTAssertFalse(hidden.isVisible(uncurated))

        XCTAssertFalse(hiddenUntilBalance.isVisible(curated))
        XCTAssertFalse(hiddenUntilBalance.isVisible(uncurated))

        XCTAssertTrue(undecided.isVisible(curated))
        XCTAssertFalse(undecided.isVisible(uncurated))

        XCTAssertTrue(fallback.isVisible(curated))
        XCTAssertFalse(fallback.isVisible(uncurated))
        XCTAssertFalse(fallback.isVisible(filtered))

        XCTAssertTrue(fallbackUndecided.isVisible(curated))
        XCTAssertTrue(fallbackUndecided.isVisible(uncurated))
    }
}
