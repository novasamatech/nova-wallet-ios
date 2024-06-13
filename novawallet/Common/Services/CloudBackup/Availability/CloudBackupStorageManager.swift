import Foundation
import Operation_iOS

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
    let cloudOperationFactory: CloudBackupOperationFactoryProtocol
    let uploadOperationFactory: CloudBackupUploadFactoryProtocol
    let notificationCenter: NotificationCenter
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    init(
        baseUrl: URL,
        cloudOperationFactory: CloudBackupOperationFactoryProtocol,
        uploadOperationFactory: CloudBackupUploadFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        notificationCenter: NotificationCenter,
        logger: LoggerProtocol
    ) {
        self.baseUrl = baseUrl
        self.cloudOperationFactory = cloudOperationFactory
        self.uploadOperationFactory = uploadOperationFactory
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

        let uploadWrapper = uploadOperationFactory.createUploadWrapper(
            for: fileUrl,
            tempUrl: nil,
            timeoutInterval: timeoutInterval,
            dataClosure: { try dataOperation.extractNoCancellableResultData() }
        )

        uploadWrapper.addDependency(operations: [dataOperation])

        let totalWrapper = uploadWrapper.insertingHead(operations: [dataOperation])

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            self?.removeFileAndNotify(
                url: fileUrl,
                result: result,
                runningIn: queue,
                completionClosure: completionClosure
            )
        }
    }

    private func removeFileAndNotify(
        url: URL,
        result: Result<Void, Error>,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping CloudBackupUploadMonitoringClosure
    ) {
        let deletionOperation = cloudOperationFactory.createDeletionOperation(for: url)

        execute(
            operation: deletionOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { [weak self] deletionResult in
            switch deletionResult {
            case .success:
                self?.complete(with: result, closure: completionClosure)
            case let .failure(error):
                self?.logger.error("File deletion failed: \(error)")
                self?.complete(with: result, closure: completionClosure)
            }
        }
    }

    private func complete(with result: Result<Void, Error>, closure: CloudBackupUploadMonitoringClosure) {
        switch result {
        case .success:
            closure(.success(()))
        case let .failure(error):
            if let uploadError = error as? CloudBackupUploadError {
                closure(.failure(uploadError))
            } else {
                closure(.failure(.internalError(error)))
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
