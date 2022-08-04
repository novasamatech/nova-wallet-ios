import XCTest
@testable import novawallet

class StakingDurationOperationFactoryTests: XCTestCase {
    func testWestend() {
        do {
            // given

            let runtimeService = try RuntimeCodingServiceStub.createWestendService()
            let operationFactory = BabeStakingDurationFactory()

            // when

            let operationWrapper = operationFactory.createDurationOperation(from: runtimeService)

            OperationQueue().addOperations(operationWrapper.allOperations, waitUntilFinished: true)

            let duration = try operationWrapper.targetOperation.extractNoCancellableResultData()

            XCTAssertEqual(duration.era, 6 * 3600)
            XCTAssertEqual(duration.unlocking, 2 * 6 * 3600)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
