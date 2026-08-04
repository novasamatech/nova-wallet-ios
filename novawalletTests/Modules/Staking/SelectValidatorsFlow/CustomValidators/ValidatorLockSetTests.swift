import XCTest
@testable import novawallet

final class ValidatorLockSetTests: XCTestCase {
    private func makeValidator(
        address: AccountAddress,
        blocked: Bool = false,
        oversubscribed: Bool = false
    ) -> SelectedValidatorInfo {
        let stakeInfo = ValidatorStakeInfo(
            nominators: oversubscribed
                ? [
                    NominatorInfo(address: "nominator1", stake: 1),
                    NominatorInfo(address: "nominator2", stake: 1)
                ]
                : [],
            totalStake: 10,
            stakeReturn: 0.1,
            maxNominatorsRewarded: 1
        )

        return SelectedValidatorInfo(
            address: address,
            identity: AccountIdentity(name: address),
            stakeInfo: stakeInfo,
            blocked: blocked
        )
    }

    private func makeModel(preferred: [SelectedValidatorInfo]) -> ElectedAndPrefValidators {
        ElectedAndPrefValidators(
            allElectedValidators: [],
            notExcludedElectedValidators: [],
            preferredValidators: preferred
        )
    }

    func testEligiblePreferredValidatorsAreLocked() {
        let model = makeModel(preferred: [makeValidator(address: "nova1")])

        XCTAssertEqual(model.lockedValidators.map(\.address), ["nova1"])
    }

    func testBlockedPreferredValidatorIsNotLocked() {
        let model = makeModel(preferred: [makeValidator(address: "nova1", blocked: true)])

        XCTAssertTrue(model.lockedValidators.isEmpty)
    }

    func testOversubscribedPreferredValidatorIsNotLocked() {
        let model = makeModel(preferred: [makeValidator(address: "nova1", oversubscribed: true)])

        XCTAssertTrue(model.lockedValidators.isEmpty)
    }

    func testFullListExposesLockedAddresses() {
        let fullList = CustomValidatorsFullList(
            allValidators: [makeValidator(address: "community1")],
            preferredValidators: [makeValidator(address: "nova1")]
        )

        XCTAssertEqual(fullList.lockedAddresses, ["nova1"])
    }
}
