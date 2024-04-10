import Foundation
import RobinHood

protocol CloudBackupStorageManaging {
    func checkStorage(
        of size: UInt64,
        timeoutInterval: TimeInterval,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping CloudBackupUploadMonitoringClosure
    )
}

enum ICloudBackupStorageManagerError: Error {
    case fileGenerationBroke
}

final class ICloudBackupStorageManager {
    let baseUrl: URL
    let operationFactory: CloudBackupOperationFactoryProtocol
    let operationQueue: OperationQueue
    let notificationCenter: NotificationCenter
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    init(
        baseUrl: URL,
        operationFactory: CloudBackupOperationFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        notificationCenter: NotificationCenter,
        logger: LoggerProtocol
    ) {
        self.baseUrl = baseUrl
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.notificationCenter = notificationCenter
        self.logger = logger
    }

    private func writeFileAndMonitor(
        of size: UInt64,
        timeoutInterval: TimeInterval,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping CloudBackupUploadMonitoringClosure
    ) {
        guard let fileName = (UUID().uuidString as NSString).appendingPathExtension("tmp") else {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(.internalError(ICloudBackupStorageManagerError.fileGenerationBroke)))
            }
            return
        }

        let fileUrl = baseUrl.appendingPathComponent(fileName, conformingTo: .plainText)

        let dataOperation = ClosureOperation<Data> {
            Data(repeating: 0, count: Int(size))
        }

        let writingOperation = operationFactory.createWritingOperation(
            for: fileUrl,
            dataClosure: { try dataOperation.extractNoCancellableResultData() }
        )

        writingOperation.addDependency(dataOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: writingOperation,
            dependencies: [dataOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success:
                let monitor = ICloudBackupUploadMonitor(
                    filename: fileUrl.lastPathComponent,
                    operationQueue: OperationQueue(),
                    notificationCenter: self.notificationCenter,
                    timeoutInteval: timeoutInterval,
                    logger: self.logger
                )

                monitor.start(runningIn: self.workingQueue) { [weak self] result in
                    monitor.stop()

                    self?.removeFileAndNotify(
                        url: fileUrl,
                        result: result,
                        runningIn: queue,
                        completionClosure: completionClosure
                    )
                }
            case let .failure(error):
                completionClosure(.failure(.internalError(error)))
            }
        }
    }

    private func removeFileAndNotify(
        url: URL,
        result: Result<Void, CloudBackupUploadError>,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping CloudBackupUploadMonitoringClosure
    ) {
        let deletionOperation = operationFactory.createDeletionOperation(for: url)

        execute(
            operation: deletionOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { [weak self] deletionResult in
            switch deletionResult {
            case .success:
                completionClosure(result)
            case let .failure(error):
                self?.logger.error("File deletion failed: \(error)")
                completionClosure(result)
            }
        }
    }
}

extension ICloudBackupStorageManager: CloudBackupStorageManaging {
    func checkStorage(
        of size: UInt64,
        timeoutInterval: TimeInterval,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping CloudBackupUploadMonitoringClosure
    ) {
        writeFileAndMonitor(
            of: size,
            timeoutInterval: timeoutInterval,
            runningIn: queue,
            completionClosure: completionClosure
        )
    }
}
