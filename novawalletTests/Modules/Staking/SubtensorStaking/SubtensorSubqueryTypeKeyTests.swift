import XCTest
@testable import novawallet

final class SubtensorSubqueryTypeKeyTests: XCTestCase {
    func testActiveStakersKeyPassesSubtensorThrough() {
        XCTAssertEqual(
            SubqueryMultistakingTypeFactory.activeStakersTypeKey(for: .subtensor, allTypes: [.subtensor]),
            "subtensor"
        )
    }

    func testRewardsKeyPassesSubtensorThrough() {
        XCTAssertEqual(
            SubqueryMultistakingTypeFactory.rewardsTypeKey(for: .subtensor),
            "subtensor"
        )
    }

    func testStakingTypeParsesSubtensorKey() {
        XCTAssertEqual(
            SubqueryMultistakingTypeFactory.stakingType(from: "subtensor"),
            .subtensor
        )
    }
}
