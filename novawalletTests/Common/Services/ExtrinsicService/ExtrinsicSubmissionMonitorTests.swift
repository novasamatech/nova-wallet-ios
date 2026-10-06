@testable import novawallet
import Operation_iOS
import XCTest

final class ExtrinsicSubmissionMonitorTests: XCTestCase {
    func testDroppedStatusEndsTheSubmissionAsNotIncluded() throws {
        let factory = ExtrinsicSubmissionMonitorFactory(
            submissionService: ExtrinsicServiceStub.dummy(watchStatus: .dropped),
            statusService: MockExtrinsicStatusServiceProtocol(),
            operationQueue: OperationQueue()
        )

        let wrapper = factory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: { $0 },
            signer: try DummySigner(cryptoType: .sr25519)
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? ExtrinsicSubmissionMonitorError, .dropped)
        }
    }
}
