import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorDelegateSelectionInfoTests: XCTestCase {
    private let delegateAccount = Data(repeating: 0x11, count: 32)
    private let ownerAccount = Data(repeating: 0x22, count: 32)
    private let nominatorAccount = Data(repeating: 0x33, count: 32)
    private let alphaOnlyNominatorAccount = Data(repeating: 0x44, count: 32)

    private func compact(_ value: UInt64) -> Data {
        if value < 64 {
            return Data([UInt8(value << 2)])
        }

        let encoded = UInt16(value << 2 | 0b01)

        return Data([UInt8(encoded & 0xFF), UInt8(encoded >> 8)])
    }

    private func encodeNominator(_ account: Data, stakes: [(UInt64, UInt64)]) -> Data {
        var result = account
        result.append(compact(UInt64(stakes.count)))

        for (netuid, stake) in stakes {
            result.append(compact(netuid))
            result.append(compact(stake))
        }

        return result
    }

    private func makeDelegate(permits: [UInt64]) throws -> SubtensorDelegate {
        var payload = Data()
        payload.append(compact(1))
        payload.append(delegateAccount)
        payload.append(compact(11796))

        payload.append(compact(3))
        payload.append(encodeNominator(ownerAccount, stakes: [(0, 100), (5, 7)]))
        payload.append(encodeNominator(nominatorAccount, stakes: [(0, 50)]))
        payload.append(encodeNominator(alphaOnlyNominatorAccount, stakes: [(5, 9)]))

        payload.append(ownerAccount)

        payload.append(compact(1))
        payload.append(compact(0))

        payload.append(compact(UInt64(permits.count)))
        permits.forEach { payload.append(compact($0)) }

        payload.append(compact(0))
        payload.append(compact(0))

        let delegates: [SubtensorStakingPallet.DelegateInfo] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: payload.toHex(includePrefix: true),
            path: SubtensorStakingPallet.delegatesApi
        )

        return SubtensorDelegate(info: try XCTUnwrap(delegates.first), identity: nil)
    }

    func testMappingSplitsOwnAndDelegatorsRootStake() throws {
        let info = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [0]),
            minStake: 2_000_000
        )

        XCTAssertEqual(info.ownStake, 100)
        XCTAssertEqual(info.delegatorsStake, 50)
        XCTAssertEqual(info.totalStake, 150)
    }

    func testMappingCountsOnlyRootNominators() throws {
        let info = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [0]),
            minStake: 2_000_000
        )

        XCTAssertEqual(info.delegationCount, 2)
    }

    func testMappingPassesThroughTakeAndMinStake() throws {
        let info = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [0]),
            minStake: 2_000_000
        )

        XCTAssertEqual(info.take, 11796)
        XCTAssertEqual(info.minRewardableStake, 2_000_000)
    }

    func testAprIsNeverExposed() throws {
        let info = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [0]),
            minStake: 2_000_000
        )

        XCTAssertNil(info.apr)
    }

    func testValidatorPermitsDriveElectedFlag() throws {
        let withPermits = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [0]),
            minStake: 2_000_000
        )

        let withoutPermits = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: []),
            minStake: 2_000_000
        )

        let otherSubnetPermit = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [5]),
            minStake: 2_000_000
        )

        XCTAssertTrue(withPermits.isElected)
        XCTAssertFalse(withoutPermits.isElected)
        XCTAssertFalse(otherSubnetPermit.isElected)
    }

    func testStatusIsNotElectedWithoutDelegation() throws {
        let info = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [0]),
            minStake: 2_000_000
        )

        let status = info.status(
            for: nominatorAccount,
            delegatorModel: nil,
            stake: 0
        )

        XCTAssertEqual(status, .notElected)
    }

    func testStatusIsRewardedForDelegationToValidatingHotkey() throws {
        let info = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: [0]),
            minStake: 2_000_000
        )

        let delegator = CollatorStakingDelegator(
            delegations: [StakingTarget(candidate: delegateAccount, amount: 50)]
        )

        let status = info.status(
            for: nominatorAccount,
            delegatorModel: delegator,
            stake: 50
        )

        XCTAssertEqual(status, .rewarded)
    }

    func testStatusIsNotRewardedForDelegationToNonValidatingHotkey() throws {
        let info = SubtensorDelegateSelectionInfo(
            delegate: try makeDelegate(permits: []),
            minStake: 2_000_000
        )

        let delegator = CollatorStakingDelegator(
            delegations: [StakingTarget(candidate: delegateAccount, amount: 50)]
        )

        let status = info.status(
            for: nominatorAccount,
            delegatorModel: delegator,
            stake: 50
        )

        XCTAssertEqual(status, .notRewarded)
    }
}
