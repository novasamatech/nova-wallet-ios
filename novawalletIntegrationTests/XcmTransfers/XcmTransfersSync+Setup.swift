import Foundation
@testable import novawallet

extension XcmTransfersSyncService {
    static func setupForIntegrationTest(
        for applicationConfig: ApplicationConfigProtocol
    ) throws -> XcmTransfers {
        let logger = Logger.shared
        let syncService = XcmTransfersSyncService(
            config: applicationConfig,
            operationQueue: OperationQueue(),
            logger: logger
        )

        var optXcmTransfers: XcmTransfers?

        let semaphore = DispatchSemaphore(value: 0)

        syncService.notificationQueue = DispatchQueue.global()

        syncService.notificationCallback = { result in
            switch result {
            case let .success(xcmTransfers):
                optXcmTransfers = xcmTransfers
            case let .failure(error):
                logger.error("Unexpected error: \(error)")
            }

            semaphore.signal()
        }

        syncService.setup()

        _ = semaphore.wait(timeout: .now() + .seconds(60))

        guard let xcmTransfers = optXcmTransfers else {
            throw CommonError.dataCorruption
        }

        return xcmTransfers
    }
}
