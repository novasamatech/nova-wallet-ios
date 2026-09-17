import XCTest
@testable import novawallet

final class AssetVisibilityPolicyTests: XCTestCase {
    func testUndecidedDefaultAssetIsVisible() {
        XCTAssertTrue(AssetVisibilityPolicy.isVisible(state: nil, isDefault: true))
    }

    func testUndecidedNonDefaultAssetIsHidden() {
        XCTAssertFalse(AssetVisibilityPolicy.isVisible(state: nil, isDefault: false))
    }

    func testVisibleOverrideShowsNonDefaultAsset() {
        XCTAssertTrue(AssetVisibilityPolicy.isVisible(state: .visible, isDefault: false))
    }

    func testHiddenOverrideHidesDefaultAsset() {
        XCTAssertFalse(AssetVisibilityPolicy.isVisible(state: .hidden, isDefault: true))
    }

    func testUserTogglePersistsRequestedState() {
        XCTAssertEqual(
            AssetVisibilityPolicy.decision(for: .userSet(isVisible: true), currentState: .hidden),
            .set(.visible)
        )
        XCTAssertEqual(
            AssetVisibilityPolicy.decision(for: .userSet(isVisible: false), currentState: .visible),
            .set(.hidden)
        )
    }

    func testPassiveBalanceRevealsUndecidedAssetWhenAutoAddIsEnabled() {
        XCTAssertEqual(
            AssetVisibilityPolicy.decision(
                for: .passivePositiveBalance(autoAddEnabled: true),
                currentState: nil
            ),
            .set(.visible)
        )
    }

    func testPassiveBalanceDoesNotRevealAssetWhenAutoAddIsDisabled() {
        XCTAssertEqual(
            AssetVisibilityPolicy.decision(
                for: .passivePositiveBalance(autoAddEnabled: false),
                currentState: nil
            ),
            .noChange
        )
    }

    func testPassiveBalanceDoesNotOverrideHiddenAsset() {
        XCTAssertEqual(
            AssetVisibilityPolicy.decision(
                for: .passivePositiveBalance(autoAddEnabled: true),
                currentState: .hidden
            ),
            .noChange
        )
    }

    func testUserInitiatedReceiptRevealsHiddenAsset() {
        XCTAssertEqual(
            AssetVisibilityPolicy.decision(for: .userInitiatedReceipt, currentState: .hidden),
            .set(.visible)
        )
    }

    func testTransitionDoesNotRewriteMatchingState() {
        XCTAssertEqual(
            AssetVisibilityPolicy.decision(for: .userSet(isVisible: true), currentState: .visible),
            .noChange
        )
    }
}
