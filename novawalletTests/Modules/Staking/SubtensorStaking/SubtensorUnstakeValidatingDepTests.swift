import BigInt
@testable import novawallet
import XCTest

final class SubtensorUnstakeValidatingDepTests: XCTestCase {
    private func makePreflight(
        availability: SubtensorStakingPallet.StakeAvailability?
    ) -> SubtensorStakingPreflight {
        SubtensorStakingPreflight(
            hotkeyExists: true,
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
        preflight: SubtensorStakingPreflight?
    ) -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
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
            onPreflightRefresh: {}
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
}
