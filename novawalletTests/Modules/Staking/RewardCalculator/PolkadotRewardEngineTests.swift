import XCTest
@testable import novawallet
import BigInt

final class PolkadotRewardEngineTests: XCTestCase {
    private let assetPrecision: Int16 = 10

    private func dot(_ whole: BigUInt) -> BigUInt {
        whole * BigUInt(10).power(Int(assetPrecision))
    }

    private func validator(index: UInt8, stake: BigUInt) -> EraValidatorInfo {
        EraValidatorInfo(
            accountId: Data(repeating: index, count: 32),
            exposure: Staking.ValidatorExposure(total: stake, own: stake, others: []),
            prefs: Staking.ValidatorPrefs(commission: 0, blocked: false)
        )
    }

    // Realistic post-DAP snapshot (verified on Polkadot Asset Hub, era ~2230):
    //   Staking.ErasValidatorReward = 69,216 DOT/era  (the DAP staker allocation, 45.2% of the
    //                                                   ~153,132 DOT daily mint)
    //   ErasTotalStake              = 862,000,000 DOT
    //   era duration                = 24h  => 365 eras/year
    // True APR = 69,216 * 365 / 862,000,000 = 2.93%.
    //
    // Regression guard: the previous engine used the Inflation runtime API's full period mint
    // (~153,132 DOT) as if it all went to stakers, producing ~6.5% average / ~8.9% max — a 2.21x
    // (= 1 / 0.452) overstatement. Driving the calc from ErasValidatorReward fixes that and needs
    // no hardcoded split.
    private func makeEngine(stakersEraReward: BigUInt) -> PolkadotRewardEngine {
        let perValidatorStake = dot(215_500_000) // 4 equal validators => 862,000,000 DOT total
        let validators = (0 ..< 4).map { validator(index: UInt8($0), stake: perValidatorStake) }

        return PolkadotRewardEngine(
            chainId: "test-chain",
            assetPrecision: assetPrecision,
            stakersEraReward: stakersEraReward,
            totalIssuance: dot(1_693_000_000),
            validators: validators,
            eraDurationInSeconds: 24 * 3600
        )
    }

    func testRestakeReturnMatchesRealisedEraReward() {
        let engine = makeEngine(stakersEraReward: dot(69216))

        let apy = engine.calculateMaxReturn(isCompound: true, period: .year)

        // Compounded (restake) annual return ≈ the base rate ≈ 2.93%.
        XCTAssertEqual((apy as NSDecimalNumber).doubleValue, 0.0293, accuracy: 0.0004)
    }

    func testNonRestakeReturnMatchesRealisedEraReward() {
        let engine = makeEngine(stakersEraReward: dot(69216))

        let apr = engine.calculateMaxReturn(isCompound: false, period: .year)

        // Simple (no restake) annual return is marginally below the compounded figure.
        XCTAssertEqual((apr as NSDecimalNumber).doubleValue, 0.0289, accuracy: 0.0004)
        XCTAssertLessThan(
            (apr as NSDecimalNumber).doubleValue,
            (engine.calculateMaxReturn(isCompound: true, period: .year) as NSDecimalNumber).doubleValue
        )
    }

    func testZeroEraRewardYieldsZeroReturn() {
        let engine = makeEngine(stakersEraReward: 0)

        XCTAssertEqual((engine.calculateMaxReturn(isCompound: true, period: .year) as NSDecimalNumber).doubleValue, 0, accuracy: 1e-9)
    }
}

final class StakingEraRewardAllocationTests: XCTestCase {
    func testEraRewardAllocationCallIdMatchesOnChainId() throws {
        // Byte-for-byte the id served in Polkadot/Kusama Asset Hub metadata v16
        // (verified against both live chains on 2026-07-14).
        let expected = try Data(
            hexString: "0x5f3e4907f716ac89b6347d15ececedca56eb9b14a6bcf65e579d5d00b3093b6c"
        )

        XCTAssertEqual(try StakingViewFunction.eraRewardAllocationCallId(), expected)
    }

    func testDecodesLiveMainnetResponse() throws {
        // Captured verbatim from Polkadot Asset Hub for era 2229 (2026-07-14):
        // staker_rewards = 69,215.6368394402 DOT, validator_incentive = 34,607.8184197201 DOT.
        let response = try Data(
            hexString: "0x0080a298773683750200000000000000000051cc3b9bc13a01000000000000000000"
        )

        let allocation = try StakingEraRewardAllocation.StateCallDecoder().decode(data: response)

        XCTAssertEqual(allocation.stakerRewards, BigUInt(692_156_368_394_402))
        XCTAssertEqual(allocation.validatorIncentive, BigUInt(346_078_184_197_201))
    }

    func testDecodesZeroAllocation() throws {
        // An era recorded outside DAP mode (or not yet completed) reads as all-zero.
        let response = Data([0x00, 0x80] + [UInt8](repeating: 0, count: 32))

        let allocation = try StakingEraRewardAllocation.StateCallDecoder().decode(data: response)

        XCTAssertEqual(allocation.stakerRewards, 0)
        XCTAssertEqual(allocation.validatorIncentive, 0)
    }

    func testThrowsOnDispatchErrorEnvelope() {
        // Err(ViewFunctionDispatchError) — e.g. NotImplemented on a runtime without
        // view function support.
        let response = Data([0x01, 0x00])

        XCTAssertThrowsError(
            try StakingEraRewardAllocation.StateCallDecoder().decode(data: response)
        )
    }

    func testThrowsOnTruncatedPayload() {
        // Ok envelope whose payload is shorter than the two expected u128 values.
        let response = Data([0x00, 0x20] + [UInt8](repeating: 0, count: 8))

        XCTAssertThrowsError(
            try StakingEraRewardAllocation.StateCallDecoder().decode(data: response)
        )
    }
}
