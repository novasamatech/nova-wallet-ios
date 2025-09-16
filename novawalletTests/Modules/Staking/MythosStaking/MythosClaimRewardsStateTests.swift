import XCTest
@testable import novawallet
import SubstrateSdk

final class MythosClaimRewardsStateTests: XCTestCase {
    func testSingleCollatorRestake() throws {
        // given

        let state = try prepareState(
            stakeDistribution: [
                "0xe07113E692708775d0Cc39E00Fe7f2974bFF4e20": 10
            ],
            reward: 1
        )

        // when

        guard let model = state.deriveModel() else {
            XCTFail("Model expected")
            return
        }

        // then

        guard let restake = model.getRestake() else {
            XCTFail("Restake expected")
            return
        }

        XCTAssertEqual(restake.lock.amount, state.claimableRewards.total)

        let stakeTargets = restake.stake.targets

        XCTAssertEqual(stakeTargets.count, 1)
        XCTAssertEqual(stakeTargets[0].stake, state.claimableRewards.total)
        XCTAssertEqual(stakeTargets[0].candidate, state.details.collatorIds.first)
    }

    func testThreeCollatorsRestakeWithRemainedAmount() throws {
        // given

        let state = try prepareState(
            stakeDistribution: [
                "0xe07113E692708775d0Cc39E00Fe7f2974bFF4e20": 5,
                "0xE6b4f55209A70384dB3D147C06b99E32fEB03d6F": 10,
                "0x4134D7194DE5Dc18c528DB601d239fA94B8FE711": 15
            ],
            reward: 1
        )

        // when

        guard let model = state.deriveModel() else {
            XCTFail("Model expected")
            return
        }

        // then

        guard let restake = model.getRestake() else {
            XCTFail("Restake expected")
            return
        }

        XCTAssertEqual(restake.lock.amount, state.claimableRewards.total)

        let stakeTargets = restake.stake.targets

        XCTAssertEqual(stakeTargets.count, 3)

        let totalStake: Balance = stakeTargets.reduce(0) { $0 + $1.stake }

        XCTAssertEqual(totalStake, state.claimableRewards.total)
    }

    func testNoRestakeForFreeBalanceStrategy() throws {
        // given

        let state = try prepareState(
            stakeDistribution: [
                "0xe07113E692708775d0Cc39E00Fe7f2974bFF4e20": 10
            ],
            reward: 1,
            claimStrategy: .freeBalance
        )

        // when

        guard let model = state.deriveModel() else {
            XCTFail("Model expected")
            return
        }

        // then

        let restake = model.getRestake()

        XCTAssertNil(restake)
    }

    func testNoRestakeWhenAutoCompound() throws {
        // given

        let state = try prepareState(
            stakeDistribution: [
                "0xe07113E692708775d0Cc39E00Fe7f2974bFF4e20": 10
            ],
            reward: 1,
            autoCompound: 100
        )

        // when

        guard let model = state.deriveModel() else {
            XCTFail("Model expected")
            return
        }

        // then

        let restake = model.getRestake()

        XCTAssertNil(restake)
    }

    private func prepareState(
        stakeDistribution: [AccountAddress: Decimal],
        reward: Decimal,
        claimStrategy: StakingClaimRewardsStrategy = .restake,
        autoCompound: Percent? = nil
    ) throws -> MythosStkClaimRewardsState {
        let convertedDistribution = try stakeDistribution.reduce(
            into: [AccountId: MythosStakingDetails.CollatorDetails]()
        ) { accum, keyValue in
            let accountId = try keyValue.key.toAccountId()
            let balance = keyValue.value.toSubstrateAmount(precision: 18)!

            accum[accountId] = .init(stake: balance, session: 0)
        }

        let details = MythosStakingDetails(stakeDistribution: convertedDistribution, maybeLastUnstake: nil)
        let rewardInPlank = reward.toSubstrateAmount(precision: 18)!

        let claimableRewards = MythosStakingClaimableRewards(total: rewardInPlank, shouldClaim: true)

        return MythosStkClaimRewardsState(
            details: details,
            claimableRewards: claimableRewards,
            claimStrategy: claimStrategy,
            autoCompound: autoCompound
        )
    }
}
