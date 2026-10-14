@testable import novawallet
import XCTest

final class SubtensorQuickPickVisitTests: XCTestCase {
    func testDuplicateDeliveryAndRefreshNeverRedraw() {
        var draws = 0
        let visit = SubtensorQuickPickVisit(order: .poolSize, selector: .init { _ in draws += 1; return 0 })
        let snapshot = SubtensorQuickPickFixtures.snapshot([.init(1), .init(2)])
        let generation = visit.beginRequest()
        XCTAssertEqual(visit.resolve(.success(snapshot), generation: generation)?.netuid, 1)
        XCTAssertNil(visit.resolve(.success(snapshot), generation: generation))
        let fresh = SubtensorQuickPickFixtures.snapshot([.init(2, pool: 9_000_000_000_000), .init(1)])
        XCTAssertEqual(visit.resolve(.success(fresh), generation: visit.beginRequest())?.netuid, 1)
        XCTAssertEqual(draws, 1)
    }

    func testMissingPriceFreezesIdentityAndRetryResolvesIt() {
        var draws = 0
        let visit = SubtensorQuickPickVisit(order: .age, selector: .init { _ in draws += 1; return 0 })
        let snapshot = SubtensorQuickPickFixtures.snapshot([.init(1), .init(2)], prices: [2: 1])
        XCTAssertNil(visit.resolve(.success(snapshot), generation: visit.beginRequest()))
        XCTAssertEqual(visit.selectedRef, SubtensorSubnetRef(netuid: 1, registeredAt: 100))
        XCTAssertNotNil(visit.error)
        XCTAssertEqual(visit.resolve(
            .success(SubtensorQuickPickFixtures.snapshot([.init(1), .init(2)])),
            generation: visit.beginRequest()
        )?.netuid, 1)
        XCTAssertEqual(draws, 1)
    }

    func testDisabledSubtokenIsReadinessFailureNotAnEligibilityFilter() {
        var draws = 0
        let visit = SubtensorQuickPickVisit(order: .poolSize, selector: .init { _ in draws += 1; return 0 })
        XCTAssertNil(visit.resolve(
            .success(SubtensorQuickPickFixtures.snapshot([.init(1)], enabled: [])),
            generation: visit.beginRequest()
        ))
        XCTAssertEqual(visit.selectedRef?.netuid, 1)
        XCTAssertNotNil(visit.resolve(
            .success(SubtensorQuickPickFixtures.snapshot([.init(1)])),
            generation: visit.beginRequest()
        ))
        XCTAssertEqual(draws, 1)
    }

    func testChangedRegistrationDoesNotSubstituteReusedNetuid() {
        let visit = SubtensorQuickPickVisit(order: .poolSize, selector: .init { _ in 0 })
        _ = visit.resolve(.success(SubtensorQuickPickFixtures.snapshot([.init(1)], prices: [:])), generation: visit.beginRequest())
        XCTAssertNil(visit.resolve(.success(SubtensorQuickPickFixtures.snapshot([.init(1, registered: 200)])), generation: visit.beginRequest()))
        XCTAssertEqual(visit.selectedRef?.registeredAt, 100)
        XCTAssertEqual(visit.error as? SubtensorQuickPickSelector.SelectionError, .registrationChanged)
    }

    func testManualReplacementAndNewRequestRejectLateCallbacks() {
        let visit = SubtensorQuickPickVisit(order: .age, selector: .init { _ in XCTFail("Late draw"); return 0 })
        let first = visit.beginRequest()
        let second = visit.beginRequest()
        let result = Result<SubtensorSubnetsInfo, Error>.success(SubtensorQuickPickFixtures.snapshot([.init(1)]))
        XCTAssertNil(visit.resolve(result, generation: first))
        visit.replaceManually()
        XCTAssertNil(visit.resolve(result, generation: second))
        XCTAssertNil(visit.selectedRef)
    }

    func testFailedAndEmptyFirstLoadsRetryAndDrawOnlyWhenReady() {
        var draws = 0
        let visit = SubtensorQuickPickVisit(order: .age, selector: .init { _ in draws += 1; return 0 })
        XCTAssertNil(visit.resolve(.failure(SubtensorQuickPickSelector.SelectionError.incompleteSnapshot), generation: visit.beginRequest()))
        XCTAssertNil(visit.resolve(.success(SubtensorQuickPickFixtures.snapshot([])), generation: visit.beginRequest()))
        XCTAssertNil(visit.selectedRef)
        XCTAssertEqual(draws, 0)
        XCTAssertNotNil(visit.resolve(.success(SubtensorQuickPickFixtures.snapshot([.init(1)])), generation: visit.beginRequest()))
        XCTAssertEqual(draws, 1)
    }

    func testBackThenChooseCreatesAnotherDrawEvenWhenOutcomeRepeats() {
        var draws = 0
        let selector = SubtensorQuickPickSelector { _ in draws += 1; return 0 }
        for _ in 0 ..< 2 {
            let visit = SubtensorQuickPickVisit(order: .age, selector: selector)
            XCTAssertEqual(visit.resolve(.success(SubtensorQuickPickFixtures.snapshot([.init(1)])), generation: visit.beginRequest())?.netuid, 1)
        }
        XCTAssertEqual(draws, 2)
    }
}
