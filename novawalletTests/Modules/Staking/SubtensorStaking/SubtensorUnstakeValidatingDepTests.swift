import BigInt
@testable import novawallet
import XCTest

final class SubtensorUnstakeValidatingDepTests: XCTestCase {
    private func makePreflight(
        availability: SubtensorStakingPallet.StakeAvailability?
    ) -> SubtensorStakingPreflight {
        SubtensorStakingPreflight(
            hotkeyExists: true,
            subnetExists: true,
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: availability,
            rootStakeUnlockInterval: 0,
            lastStakeBlock: nil,
            minStake: 2_000_000,
            effectiveNominatorMinStake: 20_000_000,
            rootClaimableThreshold: 500_000,
            delegateTake: 11796
        )
    }

    private func makeDep(
        amount: Balance?,
        stakedAmount: Balance?,
        isFullUnstake: Bool,
        preflight: SubtensorStakingPreflight?,
        quoteContext: SubtensorQuoteValidatingContext? = nil,
        netuid: UInt16 = SubtensorStakingPallet.rootNetuid
    ) -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            netuid: netuid,
            amount: amount,
            stakedAmount: stakedAmount,
            isFullUnstake: isFullUnstake,
            balance: nil,
            fee: nil,
            preflight: preflight,
            claimablePayout: nil,
            currentBlock: nil,
            blockTime: 12000,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            onFeeRefresh: {},
            onPreflightRefresh: {},
            onUnstakeAll: nil,
            quoteContext: quoteContext
        )
    }

    private func makeQuoteContext(
        alphaIn: Balance,
        taoOut: Balance?,
        spot: Balance
    ) -> SubtensorQuoteValidatingContext {
        let args = SubtensorQuoteArgs(netuid: 1, direction: .unstake(alphaIn: alphaIn))

        let quote: SubtensorQuote? = taoOut.map { taoOut in
            SubtensorQuote(
                args: args,
                sim: SubtensorStakingPallet.SimSwapResult(
                    taoAmount: taoOut,
                    alphaAmount: alphaIn,
                    taoFee: 0,
                    alphaFee: 0,
                    taoSlippage: 0,
                    alphaSlippage: 0
                ),
                spotPrice: spot,
                feeRate: 33
            )
        }

        return SubtensorQuoteValidatingContext(
            args: args,
            quote: quote,
            limitPrice: nil,
            onQuoteRefresh: {}
        )
    }

    func testAvailableIsUndefinedWithoutPreflight() {
        let dep = makeDep(amount: 100, stakedAmount: 1000, isFullUnstake: false, preflight: nil)

        XCTAssertNil(dep.availableToUnstake)
    }

    func testAvailableFallsBackToStakedWhenAvailabilityMissing() {
        let dep = makeDep(
            amount: 100,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: nil)
        )

        XCTAssertEqual(dep.availableToUnstake, 1000)
    }

    func testAvailableIsCappedByAvailability() {
        let availability = SubtensorStakingPallet.StakeAvailability(
            total: 1000,
            locked: 400,
            available: 600
        )

        let dep = makeDep(
            amount: 100,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: availability)
        )

        XCTAssertEqual(dep.availableToUnstake, 600)
    }

    func testAvailableIsCappedByPositionStake() {
        let availability = SubtensorStakingPallet.StakeAvailability(
            total: 5000,
            locked: 0,
            available: 5000
        )

        let dep = makeDep(
            amount: 100,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: availability)
        )

        XCTAssertEqual(dep.availableToUnstake, 1000)
    }

    func testRemainderIsZeroForFullUnstake() {
        let dep = makeDep(
            amount: 1000,
            stakedAmount: 1000,
            isFullUnstake: true,
            preflight: makePreflight(availability: nil)
        )

        XCTAssertEqual(dep.remainder, 0)
    }

    func testRemainderIsStakeMinusAmountForPartialUnstake() {
        let dep = makeDep(
            amount: 300,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: nil)
        )

        XCTAssertEqual(dep.remainder, 700)
    }

    func testQuotedTaoOutIsAmountWithoutQuoteContext() {
        let dep = makeDep(
            amount: 300,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: nil)
        )

        XCTAssertEqual(dep.quotedTaoOut, 300)
    }

    func testQuotedTaoOutComesFromSimulationForSubnetPosition() {
        let dep = makeDep(
            amount: 300,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: nil),
            quoteContext: makeQuoteContext(alphaIn: 300, taoOut: 150, spot: 500_000_000)
        )

        XCTAssertEqual(dep.quotedTaoOut, 150)
    }

    func testQuotedTaoOutMissingWhileSubnetQuotePending() {
        let dep = makeDep(
            amount: 300,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: nil),
            quoteContext: makeQuoteContext(alphaIn: 300, taoOut: nil, spot: 500_000_000)
        )

        XCTAssertNil(dep.quotedTaoOut)
    }

    func testRemainderTaoValueScalesAlphaBySpotPrice() {
        let dep = makeDep(
            amount: 300,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: nil),
            quoteContext: makeQuoteContext(alphaIn: 300, taoOut: 150, spot: 500_000_000)
        )

        XCTAssertEqual(dep.remainderTaoValue, 350)
    }

    func testRemainderTaoValueEqualsRemainderOnRoot() {
        let dep = makeDep(
            amount: 300,
            stakedAmount: 1000,
            isFullUnstake: false,
            preflight: makePreflight(availability: nil)
        )

        XCTAssertEqual(dep.remainderTaoValue, 700)
    }
}
