import Foundation
import RobinHood

protocol CloudBackupUploadFactoryProtocol {
    /**
     *  Uploads a data to the temp url first and in case of success moves file to the fileUrl.
     *  This allows us to prevent cases when the file is changed but a user is not authorized to perform uploading.
     */
    func createUploadWrapper(
        for fileUrl: URL,
        tempUrl: URL?,
        timeoutInterval: TimeInterval,
        dataClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>
}

final class ICloudBackupUploadFactory {
    let operationFactory: CloudBackupOperationFactoryProtocol
    let monitoringOperationQueue: OperationQueue
    let notificationCenter: NotificationCenter
    let logger: LoggerProtocol

    init(
        operationFactory: CloudBackupOperationFactoryProtocol,
        monitoringOperationQueue: OperationQueue,
        notificationCenter: NotificationCenter,
        logger: LoggerProtocol
    ) {
        self.operationFactory = operationFactory
        self.monitoringOperationQueue = monitoringOperationQueue
        self.notificationCenter = notificationCenter
        self.logger = logger
    }
}

extension ICloudBackupUploadFactory: CloudBackupUploadFactoryProtocol {
    func createUploadWrapper(
        for fileUrl: URL,
        tempUrl: URL?,
        timeoutInterval: TimeInterval,
        dataClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        let writingUrl = tempUrl ?? fileUrl
        let writeOperation = operationFactory.createWritingOperation(for: writingUrl) {
            try dataClosure()
        }

        let uploadMonitoring = ICloudBackupUploadMonitor(
            filename: writingUrl.lastPathComponent,
            operationQueue: monitoringOperationQueue,
            workingQueue: DispatchQueue.global(),
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

        if let tempUrl {
            let moveOperation = operationFactory.createMoveOperation(
                from: tempUrl,
                destinationUrl: fileUrl
            )

            moveOperation.configurationBlock = {
                do {
                    // make sure upload is successfull before moving
                    try uploadOperation.extractNoCancellableResultData()
                } catch {
                    moveOperation.result = .failure(error)
                }
            }

            moveOperation.addDependency(uploadOperation)

            return CompoundOperationWrapper(
                targetOperation: moveOperation,
                dependencies: [writeOperation, uploadOperation]
            )

        } else {
            return CompoundOperationWrapper(targetOperation: uploadOperation, dependencies: [writeOperation])
        }
    }
}
