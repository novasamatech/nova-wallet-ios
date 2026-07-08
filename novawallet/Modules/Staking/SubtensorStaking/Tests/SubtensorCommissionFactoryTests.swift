import XCTest
@testable import novawallet
import BigInt

final class SubtensorCommissionFactoryTests: XCTestCase {
    private let callFactory = SubstrateCallFactory()
    private let dummyFeeAccountId: AccountId = Data(repeating: 1, count: 32)

    // MARK: - Stake

    func testSubnetStakeProduces03PercentFee() {
        // given
        let gross: BigUInt = 1_000_000_000 // 1 TAO in RAO

        // when
        let result = SubtensorCommissionFactory.makeStakeCommission(
            gross: gross,
            netuid: 1,
            feeAccountId: dummyFeeAccountId,
            callFactory: callFactory
        )

        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.commissionAmount, 3_000_000)
    }

    func testRootStakeReturnsNil() {
        // given
        let gross: BigUInt = 1_000_000_000

        // when
        let result = SubtensorCommissionFactory.makeStakeCommission(
            gross: gross,
            netuid: SubtensorStakingConstants.rootNetuid,
            feeAccountId: dummyFeeAccountId,
            callFactory: callFactory
        )

        // then
        XCTAssertNil(result)
    }

    // MARK: - Unstake

    func testSubnetUnstakeProduces03PercentFee() {
        // given
        let minTaoOut: BigUInt = 2_000_000_000 // 2 TAO in RAO

        // when
        let result = SubtensorCommissionFactory.makeUnstakeCommission(
            minTaoOut: minTaoOut,
            netuid: 8,
            feeAccountId: dummyFeeAccountId,
            callFactory: callFactory
        )

        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.commissionAmount, 6_000_000)
    }

    // MARK: - Nil recipient

    func testNilFeeAccountIdReturnsNil() {
        // given
        let gross: BigUInt = 1_000_000_000

        // when
        let result = SubtensorCommissionFactory.makeStakeCommission(
            gross: gross,
            netuid: 1,
            feeAccountId: nil,
            callFactory: callFactory
        )

        // then
        XCTAssertNil(result)
    }

    // MARK: - Dust rounding boundary

    // The fee is floor(gross * 30 / 10000). Below ~334 plank it rounds to 0, in
    // which case the factory must return nil (no fee leg, full amount staked) so
    // the entry/confirm rows stay hidden and the extrinsic charges nothing.

    func testStakeFeeRoundingToZeroReturnsNil() {
        // 333 * 30 / 10000 == 0 (integer floor)
        let result = SubtensorCommissionFactory.makeStakeCommission(
            gross: 333,
            netuid: 1,
            feeAccountId: dummyFeeAccountId,
            callFactory: callFactory
        )

        XCTAssertNil(result)
    }

    func testStakeFeeJustAboveDustProducesOneRaoFee() {
        // 334 * 30 / 10000 == 1 (integer floor) — smallest non-zero fee
        let result = SubtensorCommissionFactory.makeStakeCommission(
            gross: 334,
            netuid: 1,
            feeAccountId: dummyFeeAccountId,
            callFactory: callFactory
        )

        XCTAssertEqual(result?.commissionAmount, 1)
    }

    func testUnstakeFeeRoundingToZeroReturnsNil() {
        let result = SubtensorCommissionFactory.makeUnstakeCommission(
            minTaoOut: 333,
            netuid: 8,
            feeAccountId: dummyFeeAccountId,
            callFactory: callFactory
        )

        XCTAssertNil(result)
    }

    // NOTE: batchAll leg ORDER (stake: transfer_keep_alive then add_stake_limit;
    // unstake: remove_stake_limit then transfer_keep_alive) lives in each
    // interactor's buildExtrinsicClosure, not this factory, so it is verified by
    // on-chain QA rather than here — the factory only builds the fee leg itself.
}
