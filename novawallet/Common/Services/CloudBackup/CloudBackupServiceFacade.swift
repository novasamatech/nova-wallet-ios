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

    private func createImportWrapper(
        for fileUrl: URL,
        using keystore: KeystoreProtocol,
        password: String
    ) -> CompoundOperationWrapper<Set<MetaAccountModel>> {
        let secretsImporter = serviceFactory.createSecretsImporter(to: keystore)
        let decodingManager = serviceFactory.createCodingManager()

        let readingOperation = serviceFactory.createOperationFactory().createReadingOperation(for: fileUrl)

        let decodingOperation = ClosureOperation<CloudBackup.EncryptedFileModel> {
            guard let data = try readingOperation.extractNoCancellableResultData() else {
                throw CloudBackupServiceFacadeError.noBackup
            }

            do {
                return try decodingManager.decode(data: data)
            } catch {
                throw CloudBackupServiceFacadeError.backupDecoding(error)
            }
        }

        decodingOperation.addDependency(readingOperation)

        let importOperation = ClosureOperation<Set<MetaAccountModel>> {
            let encryptedModel = try decodingOperation.extractNoCancellableResultData()

            guard !encryptedModel.publicData.wallets.isEmpty else {
                return []
            }

            do {
                let wallets = try secretsImporter.importBackup(
                    from: encryptedModel,
                    password: password,
                    onlyWallets: nil
                )

                return wallets
            } catch let CloudBackupSecretsImportingError.decodingFailed(innerError) {
                throw CloudBackupServiceFacadeError.backupDecoding(innerError)
            } catch CloudBackupSecretsImportingError.decryptionFailed {
                throw CloudBackupServiceFacadeError.invalidBackupPassword
            }
        }

        importOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: importOperation,
            dependencies: [readingOperation, decodingOperation]
        )
    }
}

extension CloudBackupServiceFacade: CloudBackupServiceFacadeProtocol {
    func createBackup(
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
            timeoutInterval: CloudBackup.backupSaveTimeout,
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

    func importBackup(
        to repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        keystore: KeystoreProtocol,
        password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Set<MetaAccountModel>, CloudBackupServiceFacadeError>) -> Void
    ) {
        let fileManager = serviceFactory.createFileManager()

        guard let fileUrl = fileManager.getFileUrl() else {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(.cloudNotAvailable))
            }
            return
        }

        let importWrapper = createImportWrapper(for: fileUrl, using: keystore, password: password)

        let saveOperation = repository.saveOperation({
            let wallets = try importWrapper.targetOperation.extractNoCancellableResultData()
            return wallets.enumerated().map { index, wallet in
                ManagedMetaAccountModel(
                    info: wallet,
                    isSelected: index == 0,
                    order: UInt32(index)
                )
            }
        }, {
            []
        })

        saveOperation.addDependency(importWrapper.targetOperation)

        execute(
            wrapper: importWrapper.insertingTail(operation: saveOperation),
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case .success:
                do {
                    let wallets = try importWrapper.targetOperation.extractNoCancellableResultData()
                    completionClosure(.success(wallets))
                } catch {
                    completionClosure(.failure(.facadeInternal(error)))
                }
            case let .failure(error):
                if let facadeError = error as? CloudBackupServiceFacadeError {
                    completionClosure(.failure(facadeError))
                } else {
                    completionClosure(.failure(.facadeInternal(error)))
                }
            }
        }
    }

    func deleteBackup(
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

        let deletionOperation = serviceFactory.createOperationFactory().createDeletionOperation(for: fileUrl)

        execute(
            operation: deletionOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case .success:
                completionClosure(.success(()))
            case let .failure(error):
                completionClosure(.failure(.backupDelete(error)))
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
