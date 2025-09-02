import Foundation
import Keystore_iOS
import Operation_iOS

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

        guard
            let fileUrl = fileManager.getFileUrl() else {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(.cloudNotAvailable))
            }
            return
        }

        let readBackupOperation = serviceFactory.createOperationFactory().createReadingOperation(
            for: fileUrl
        )

        let exporter = serviceFactory.createSecretsExporter(from: keystore)
        let encoder = serviceFactory.createCodingManager()

        let modifiedAt = UInt64(Date().timeIntervalSince1970)

        let dataOperation = ClosureOperation<Data> {
            let existingData = try readBackupOperation.extractNoCancellableResultData()

            if existingData != nil {
                throw CloudBackupServiceFacadeError.backupAlreadyExists
            }

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

        dataOperation.addDependency(readBackupOperation)

        let writingOperation = serviceFactory.createOperationFactory().createWritingOperation(
            for: fileUrl
        ) {
            try dataOperation.extractNoCancellableResultData()
        }

        writingOperation.addDependency(dataOperation)

        let totalWrapper = CompoundOperationWrapper(
            targetOperation: writingOperation,
            dependencies: [readBackupOperation, dataOperation]
        )

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

    func checkBackupPassword(
        _ password: String,
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

        let cryptoManager = serviceFactory.createCryptoManager()

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

        let passwordCheckOperation = ClosureOperation<Bool> {
            let encryptedModel = try decodingOperation.extractNoCancellableResultData()

            guard let data = try? Data(hexString: encryptedModel.privateData) else {
                throw CloudBackupServiceFacadeError.backupDecoding(CommonError.dataCorruption)
            }

            let optDecoded = try? cryptoManager.decrypt(data: data, password: password)

            return optDecoded != nil
        }

        passwordCheckOperation.addDependency(decodingOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: passwordCheckOperation,
            dependencies: [readingOperation, decodingOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(isValidPassword):
                completionClosure(.success(isValidPassword))
            case let .failure(error):
                if let facadeError = error as? CloudBackupServiceFacadeError {
                    completionClosure(.failure(facadeError))
                } else {
                    completionClosure(.failure(.facadeInternal(error)))
                }
            }
        }
    }

    func changeBackupPassword(
        from oldPassword: String,
        newPassword: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    ) {
        let fileManager = serviceFactory.createFileManager()

        guard
            let fileUrl = fileManager.getFileUrl() else {
            dispatchInQueueWhenPossible(queue) { completionClosure(.failure(.cloudNotAvailable)) }
            return
        }

        let cryptoManager = serviceFactory.createCryptoManager()

        let codingManager = serviceFactory.createCodingManager()

        let readingOperation = serviceFactory.createOperationFactory().createReadingOperation(for: fileUrl)

        let encryptingOperation = ClosureOperation<Data> {
            guard let data = try readingOperation.extractNoCancellableResultData() else {
                throw CloudBackupServiceFacadeError.noBackup
            }

            let encryptedModel = try codingManager.decode(data: data)
            let privateData = try Data(hexString: encryptedModel.privateData)
            let privateDecoded = try cryptoManager.decrypt(data: privateData, password: oldPassword)
            let privateEncoded = try cryptoManager.encrypt(data: privateDecoded, password: newPassword)

            let model = CloudBackup.EncryptedFileModel(
                publicData: encryptedModel.publicData,
                privateData: privateEncoded.toHex()
            )

            return try codingManager.encode(backup: model)
        }

        encryptingOperation.addDependency(readingOperation)

        let writeOperation = serviceFactory.createOperationFactory().createWritingOperation(
            for: fileUrl
        ) {
            try encryptingOperation.extractNoCancellableResultData()
        }

        writeOperation.addDependency(encryptingOperation)

        let totalWrapper = CompoundOperationWrapper(
            targetOperation: writeOperation,
            dependencies: [readingOperation, encryptingOperation]
        )

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case .success:
                completionClosure(.success(()))
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
