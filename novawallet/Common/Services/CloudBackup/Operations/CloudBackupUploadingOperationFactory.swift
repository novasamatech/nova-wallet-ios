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
    let operationQueue: OperationQueue
    let monitoringQueue: DispatchQueue
    let notificationCenter: NotificationCenter
    let timeoutInterval: TimeInterval
    let logger: LoggerProtocol

    init(
        operationFactory: CloudBackupOperationFactoryProtocol,
        operationQueue: OperationQueue,
        monitoringQueue: DispatchQueue,
        notificationCenter: NotificationCenter,
        timeoutInterval: TimeInterval,
        logger: LoggerProtocol
    ) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.monitoringQueue = monitoringQueue
        self.notificationCenter = notificationCenter
        self.timeoutInterval = timeoutInterval
        self.logger = logger
    }

    private func createUploadWrapper(
        for fileUrl: URL,
        dataClosure: @escaping () throws -> Data,
        monitorInQueue: DispatchQueue
    ) -> CompoundOperationWrapper<Void> {
        let writeOperation = operationFactory.createWritingOperation(for: fileUrl) {
            try dataClosure()
        }

        let uploadMonitoring = ICloudBackupUploadMonitor(
            filename: fileUrl.lastPathComponent,
            operationQueue: operationQueue,
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

                uploadMonitoring.start(runningIn: monitorInQueue) { result in
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

extension ICloudBackupUploadFactory: CloudBackupUploadFactoryProtocol {
    func createUploadWrapper(
        for fileUrl: URL,
        dataClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        createUploadWrapper(
            for: fileUrl,
            dataClosure: dataClosure,
            monitorInQueue: monitoringQueue
        )
    }
}
