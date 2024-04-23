import Foundation
import SoraKeystore
import RobinHood

final class CloudBackupServiceFacade {
    let serviceFactory: CloudBackupServiceFactoryProtocol
    let operationQueue: OperationQueue

    init(
        serviceFactory: CloudBackupServiceFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.serviceFactory = serviceFactory
        self.operationQueue = operationQueue
    }
}

extension CloudBackupServiceFacade: CloudBackupServiceFacadeProtocol {
    func enableBackup(
        wallets: Set<MetaAccountModel>,
        keystore: KeystoreProtocol,
        password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    ) {
        let fileManager = serviceFactory.createFileManager()

        guard let fileUrl = fileManager.getFileUrl() else {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(.cloudNotAvailable))
            }
            return
        }

        let exporter = serviceFactory.createSecretsExporter(from: keystore)
        let encoder = serviceFactory.createCodingManager()

        // TODO: Save modification date locally
        let modifiedAt = UInt64(Date().timeIntervalSince1970)

        let dataOperation = ClosureOperation<Data> {
            do {
                let model = try exporter.backup(
                    wallets: wallets,
                    password: password,
                    modifiedAt: modifiedAt
                )

                return try encoder.encode(backup: model)
            } catch {
                throw CloudBackupServiceFacadeError.backupExport(error)
            }
        }

        let uploadWrapper = serviceFactory.createUploadFactory().createUploadWrapper(
            for: fileUrl,
            dataClosure: {
                try dataOperation.extractNoCancellableResultData()
            }
        )

        uploadWrapper.addDependency(operations: [dataOperation])

        let totalWrapper = uploadWrapper.insertingHead(operations: [dataOperation])

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case .success:
                completionClosure(.success(()))
            case let .failure(error):
                if let facadeError = error as? CloudBackupServiceFacadeError {
                    completionClosure(.failure(facadeError))
                } else {
                    completionClosure(.failure(.backupUpload(error)))
                }
            }
        }
    }

    func checkBackupExists(
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Bool, CloudBackupServiceFacadeError>) -> Void
    ) {
        let fileManager = serviceFactory.createFileManager()
        guard let fileUrl = fileManager.getFileUrl() else {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(.cloudNotAvailable))
            }

            return
        }

        let cloudOperationFactory = serviceFactory.createOperationFactory()
        let readOperation = cloudOperationFactory.createReadingOperation(for: fileUrl)

        execute(
            operation: readOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(model):
                let hasBackup = model != nil
                completionClosure(.success(hasBackup))
            case let .failure(error):
                if let facadeError = error as? CloudBackupServiceFacadeError {
                    completionClosure(.failure(facadeError))
                } else {
                    completionClosure(.failure(.facadeInternal(error)))
                }
            }
        }
    }
}
