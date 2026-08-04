import XCTest
@testable import novawallet

final class ValidatorSelectionSeederTests: XCTestCase {
    private func makeValidator(_ address: AccountAddress, stakeReturn: Decimal) -> SelectedValidatorInfo {
        SelectedValidatorInfo(
            address: address,
            identity: AccountIdentity(name: address),
            stakeInfo: ValidatorStakeInfo(totalStake: 10, stakeReturn: stakeReturn)
        )
    }

    func testLockedValidatorsAreAlwaysIncluded() {
        let targets = [makeValidator("community1", stakeReturn: 0.5)]
        let locked = [makeValidator("nova1", stakeReturn: 0.1)]

        let result = ValidatorSelectionSeeder.seed(
            initialTargets: targets,
            lockedValidators: locked,
            maxNominations: 16
        )

        XCTAssertEqual(result.map(\.address), ["community1", "nova1"])
    }

    func testCommunityValidatorsAreDroppedToMakeRoom() {
        let targets = (0 ..< 3).map { makeValidator("community\($0)", stakeReturn: Decimal($0) / 10) }
        let locked = [makeValidator("nova1", stakeReturn: 0.9)]

        let result = ValidatorSelectionSeeder.seed(
            initialTargets: targets,
            lockedValidators: locked,
            maxNominations: 3
        )

        // community2 (0.2) and community1 (0.1) survive, community0 (0.0) is dropped
        XCTAssertEqual(result.map(\.address), ["community2", "community1", "nova1"])
    }

    func testSelectionNeverExceedsMaxNominations() {
        let targets = (0 ..< 20).map { makeValidator("community\($0)", stakeReturn: Decimal($0) / 100) }
        let locked = (0 ..< 4).map { makeValidator("nova\($0)", stakeReturn: 0.9) }

        let result = ValidatorSelectionSeeder.seed(
            initialTargets: targets,
            lockedValidators: locked,
            maxNominations: 16
        )

        XCTAssertEqual(result.count, 16)
        XCTAssertEqual(result.suffix(4).map(\.address), ["nova0", "nova1", "nova2", "nova3"])
    }

    func testLockedValidatorsAlreadyInTargetsAreNotDuplicated() {
        let locked = [makeValidator("nova1", stakeReturn: 0.9)]
        let targets = [makeValidator("community1", stakeReturn: 0.5)] + locked

        let result = ValidatorSelectionSeeder.seed(
            initialTargets: targets,
            lockedValidators: locked,
            maxNominations: 16
        )

        XCTAssertEqual(result.map(\.address), ["community1", "nova1"])
    }

    func testMoreLockedValidatorsThanSlots() {
        let targets = [makeValidator("community1", stakeReturn: 0.5)]
        let locked = (0 ..< 3).map { makeValidator("nova\($0)", stakeReturn: 0.9) }

        let result = ValidatorSelectionSeeder.seed(
            initialTargets: targets,
            lockedValidators: locked,
            maxNominations: 2
        )

        XCTAssertEqual(result.map(\.address), ["nova0", "nova1"])
    }

    func testEmptyLockSetKeepsTargetsCapped() {
        let targets = (0 ..< 5).map { makeValidator("community\($0)", stakeReturn: Decimal($0) / 10) }

        let result = ValidatorSelectionSeeder.seed(
            initialTargets: targets,
            lockedValidators: [],
            maxNominations: 3
        )

        XCTAssertEqual(result.map(\.address), ["community4", "community3", "community2"])
    }
}
