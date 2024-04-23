import Foundation
import RobinHood

protocol CloudBackupUploadFactoryProtocol {
    func createUploadWrapper(
        for fileUrl: URL,
        dataClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>
}

final class ICloudBackupUploadFactory {
    let operationFactory: CloudBackupOperationFactoryProtocol
    let monitoringOperationQueue: OperationQueue
    let notificationCenter: NotificationCenter
    let timeoutInterval: TimeInterval
    let logger: LoggerProtocol

    init(
        operationFactory: CloudBackupOperationFactoryProtocol,
        monitoringOperationQueue: OperationQueue,
        notificationCenter: NotificationCenter,
        timeoutInterval: TimeInterval,
        logger: LoggerProtocol
    ) {
        self.operationFactory = operationFactory
        self.monitoringOperationQueue = monitoringOperationQueue
        self.notificationCenter = notificationCenter
        self.timeoutInterval = timeoutInterval
        self.logger = logger
    }
}

extension ICloudBackupUploadFactory: CloudBackupUploadFactoryProtocol {
    func createUploadWrapper(
        for fileUrl: URL,
        dataClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        let writeOperation = operationFactory.createWritingOperation(for: fileUrl) {
            try dataClosure()
        }

        let uploadMonitoring = ICloudBackupUploadMonitor(
            filename: fileUrl.lastPathComponent,
            operationQueue: monitoringOperationQueue,
            notificationCenter: notificationCenter,
            timeoutInteval: timeoutInterval,
            logger: logger
        )

        let uploadOperation = AsyncClosureOperation<Void>(
            cancelationClosure: {
                uploadMonitoring.stop()
            },
            operationClosure: { completionClosure in
                _ = try writeOperation.extractNoCancellableResultData()

                uploadMonitoring.start { result in
                    uploadMonitoring.stop()

                    switch result {
                    case .success:
                        completionClosure(.success(()))
                    case let .failure(error):
                        completionClosure(.failure(error))
                    }
                }
            }
        )

        uploadOperation.addDependency(writeOperation)

        return CompoundOperationWrapper(targetOperation: uploadOperation, dependencies: [writeOperation])
    }
}