import XCTest
@testable import novawallet

final class ValidatorSelectionCounterTests: XCTestCase {
    private func makeValidator(_ address: AccountAddress) -> SelectedValidatorInfo {
        SelectedValidatorInfo(address: address, identity: AccountIdentity(name: address))
    }

    func testCountsExcludeLockedValidators() {
        let counter = ValidatorSelectionCounter(lockedAddresses: ["nova1", "nova2"], maxNominations: 16)

        let state = counter.state(for: [
            makeValidator("nova1"),
            makeValidator("nova2"),
            makeValidator("community1")
        ])

        XCTAssertEqual(state.communitySelected, 1)
        XCTAssertEqual(state.communityLimit, 14)
        XCTAssertEqual(state.lockedSelected, 2)
    }

    func testLockedValidatorsNotYetSelectedDoNotReduceTheLimit() {
        let counter = ValidatorSelectionCounter(lockedAddresses: ["nova1", "nova2"], maxNominations: 16)

        let state = counter.state(for: [makeValidator("community1")])

        XCTAssertEqual(state.communitySelected, 1)
        XCTAssertEqual(state.communityLimit, 16)
        XCTAssertEqual(state.lockedSelected, 0)
    }

    func testLimitIsClampedAtZero() {
        let counter = ValidatorSelectionCounter(
            lockedAddresses: ["nova1", "nova2", "nova3"],
            maxNominations: 2
        )

        let state = counter.state(for: [
            makeValidator("nova1"),
            makeValidator("nova2"),
            makeValidator("nova3")
        ])

        XCTAssertEqual(state.communitySelected, 0)
        XCTAssertEqual(state.communityLimit, 0)
        XCTAssertEqual(state.lockedSelected, 3)
    }

    func testEmptyLockSet() {
        let counter = ValidatorSelectionCounter(lockedAddresses: [], maxNominations: 16)

        let state = counter.state(for: [makeValidator("community1"), makeValidator("community2")])

        XCTAssertEqual(state.communitySelected, 2)
        XCTAssertEqual(state.communityLimit, 16)
        XCTAssertEqual(state.lockedSelected, 0)
    }
}
