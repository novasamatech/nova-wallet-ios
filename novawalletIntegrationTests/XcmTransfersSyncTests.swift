import XCTest
@testable import novawallet

class XcmTransfersSyncTests: XCTestCase {
    func testXcmTransfersSyncCompletes() {
        let logger = Logger.shared
        let syncService = XcmTransfersSyncService(
            config: ApplicationConfig.shared,
            operationQueue: OperationQueue(),
            logger: logger
        )

        var optXcmTransfers: XcmTransfers?

        let expectation = XCTestExpectation()

        syncService.notificationCallback = { result in
            switch result {
            case let .success(xcmTransfers):
                optXcmTransfers = xcmTransfers
            case let .failure(error):
                logger.error("Unexpected error: \(error)")
            }

            expectation.fulfill()
        }

        syncService.setup()

        wait(for: [expectation], timeout: 10.0)

        guard let xcmTransfers = optXcmTransfers else {
            XCTFail("Unexpected empty value")
            return
        }

        logger.info("\(xcmTransfers)")
    }
}
