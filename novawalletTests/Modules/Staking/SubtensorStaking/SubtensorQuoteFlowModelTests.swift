import BigInt
@testable import novawallet
import XCTest

final class SubtensorQuoteFlowModelTests: XCTestCase {
    private let stakeArgs = SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 1_000_000_000))

    private func makeQuote(for args: SubtensorQuoteArgs) -> SubtensorQuote {
        SubtensorQuote(
            args: args,
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 999_496_453,
                alphaAmount: 130_082_405_209,
                taoFee: 503_547,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 70_762_340
            ),
            spotPrice: 7_683_255,
            feeRate: 33
        )
    }

    private func makeSubnetTarget(netuid: UInt16 = 1) -> SubtensorStakeTarget {
        .subnet(
            info: SubtensorStakingPallet.DynamicInfo(
                netuid: netuid,
                ownerHotkey: Data(repeating: 0, count: 32),
                ownerColdkey: Data(repeating: 0, count: 32),
                subnetName: Data("Apex".utf8),
                tokenSymbol: Data("α".utf8),
                tempo: 99,
                lastStep: 0,
                blocksSinceLastStep: 0,
                emission: 0,
                alphaIn: 0,
                alphaOut: 0,
                taoIn: 0,
                alphaOutEmission: 0,
                alphaInEmission: 0,
                taoInEmission: 0,
                pendingAlphaEmission: 0,
                pendingRootEmission: 0,
                subnetVolume: 0,
                networkRegisteredAt: 0,
                subnetIdentity: nil,
                movingPrice: .null
            ),
            price: 7_683_255
        )
    }

    func testRootTargetProducesNoStakeArgs() {
        XCTAssertNil(SubtensorQuoteFlowModel.stakeArgs(for: .root, amount: 1_000_000_000))
    }

    func testRootTargetProducesNoUnstakeArgs() {
        XCTAssertNil(SubtensorQuoteFlowModel.unstakeArgs(for: .root, amount: 1_000_000_000))
    }

    func testZeroAmountProducesNoArgs() {
        XCTAssertNil(SubtensorQuoteFlowModel.stakeArgs(for: makeSubnetTarget(), amount: 0))
    }

    func testSubnetStakeArgsCarryNetuidAndTaoDirection() {
        let args = SubtensorQuoteFlowModel.stakeArgs(for: makeSubnetTarget(netuid: 5), amount: 42)

        XCTAssertEqual(args, SubtensorQuoteArgs(netuid: 5, direction: .stake(taoIn: 42)))
    }

    func testSubnetUnstakeArgsCarryAlphaDirection() {
        let args = SubtensorQuoteFlowModel.unstakeArgs(for: makeSubnetTarget(netuid: 5), amount: 42)

        XCTAssertEqual(args, SubtensorQuoteArgs(netuid: 5, direction: .unstake(alphaIn: 42)))
    }

    func testChangingArgsRequestsRefreshAndClearsQuote() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateArgs(stakeArgs)
        XCTAssertTrue(model.applyQuote(makeQuote(for: stakeArgs)))

        let newArgs = SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 2_000_000_000))
        let refreshArgs = model.updateArgs(newArgs)

        XCTAssertEqual(refreshArgs, newArgs)
        XCTAssertNil(model.freshQuote)
    }

    func testUnchangedArgsRequestNoRefresh() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateArgs(stakeArgs)

        XCTAssertNil(model.updateArgs(stakeArgs))
    }

    func testStaleQuoteForDifferentArgsIsRejected() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateArgs(stakeArgs)

        let staleArgs = SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 7))

        XCTAssertFalse(model.applyQuote(makeQuote(for: staleArgs)))
        XCTAssertNil(model.freshQuote)
    }

    func testMatchingQuoteBecomesFresh() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateArgs(stakeArgs)

        XCTAssertTrue(model.applyQuote(makeQuote(for: stakeArgs)))
        XCTAssertEqual(model.freshQuote?.args, stakeArgs)
    }

    func testClearingArgsDropsQuote() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateArgs(stakeArgs)
        _ = model.applyQuote(makeQuote(for: stakeArgs))

        XCTAssertNil(model.updateArgs(nil))
        XCTAssertNil(model.freshQuote)
        XCTAssertNil(model.args)
    }

    func testClearQuoteDropsQuoteButKeepsArgs() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateArgs(stakeArgs)
        _ = model.applyQuote(makeQuote(for: stakeArgs))

        model.clearQuote()

        XCTAssertNil(model.freshQuote)
        XCTAssertEqual(model.args, stakeArgs)
    }
}
