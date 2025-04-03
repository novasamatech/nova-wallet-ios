import Foundation
import SubstrateSdk
import Operation_iOS

enum XcmTransfersSyncServiceError: Error {
    case invalidLocalFile(remote: URL)
}

protocol XcmGenericTransfersSyncServiceProtocol: AnyObject, ApplicationServiceProtocol {
    associatedtype XcmTransfersType

    var notificationCallback: ((Result<XcmTransfersType, Error>) -> Void)? { get set }
    var notificationQueue: DispatchQueue { get set }
}

typealias XcmLegacyTransfersSyncService = XcmGenericTransfersSyncService<XcmLegacyTransfers>
typealias XcmDynamicTransfersSyncService = XcmGenericTransfersSyncService<XcmDynamicTransfers>

final class XcmGenericTransfersSyncService<X: Decodable>: BaseSyncService, XcmGenericTransfersSyncServiceProtocol {
    typealias XcmTranferType = X

    struct FetchResult {
        let data: Data?
        let transfers: X?
    }

    let remoteUrl: URL
    let fileDownloader: DataOperationFactoryProtocol
    let fileRepository: FileRepositoryProtocol
    let fileManager: FileManager
    let operationQueue: OperationQueue

    var notificationCallback: ((Result<X, Error>) -> Void)?
    var notificationQueue = DispatchQueue.main

    private var operations: [Operation]?

    init(
        remoteUrl: URL,
        operationQueue: OperationQueue,
        fileDownloader: DataOperationFactoryProtocol = DataOperationFactory(),
        fileRepository: FileRepositoryProtocol = FileRepository(),
        fileManager: FileManager = FileManager.default,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.remoteUrl = remoteUrl
        self.fileDownloader = fileDownloader
        self.fileRepository = fileRepository
        self.fileManager = fileManager
        self.operationQueue = operationQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    private func creteLocalFilePath() -> String? {
        let remoteFilename = remoteUrl.lastPathComponent

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        return cachesDirectory?.appendingPathComponent(remoteFilename).absoluteString
    }

    private func notify(with result: Result<XcmTransfersType, Error>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let notificationCallback = notificationCallback else {
            return
        }

        notificationQueue.async {
            notificationCallback(result)
        }
    }

    private func clearOperations() -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let exists = operations != nil

        operations = nil

        return exists
    }

    private func createLocalWrapper(for localPath: String) -> CompoundOperationWrapper<FetchResult> {
        let fetchOperation = fileRepository.readOperation(at: localPath)
        let decodingOperation = ClosureOperation<FetchResult> {
            let data = try? fetchOperation.extractNoCancellableResultData()
            let transfers = data.flatMap { try? JSONDecoder().decode(XcmTransfersType.self, from: $0) }

            return FetchResult(data: data, transfers: transfers)
        }

        decodingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: decodingOperation, dependencies: [fetchOperation])
    }

    private func createRemoteWrapper(
        dependingOn localOperation: BaseOperation<FetchResult>,
        localPath: String
    ) -> CompoundOperationWrapper<XcmTransfersType?> {
        let fetchRemoteOperation = fileDownloader.fetchData(from: remoteUrl)

        let newDataOperation = ClosureOperation<Data?> {
            let localData = try? localOperation.extractNoCancellableResultData().data
            let remoteData = try fetchRemoteOperation.extractNoCancellableResultData()

            if localData != remoteData {
                return remoteData
            } else {
                return nil
            }
        }

        newDataOperation.addDependency(fetchRemoteOperation)

        let saveFileOperation = fileRepository.writeOperation(
            dataClosure: {
                try fetchRemoteOperation.extractNoCancellableResultData()
            },
            at: localPath
        )

        saveFileOperation.addDependency(newDataOperation)

        saveFileOperation.configurationBlock = {
            do {
                let newData = try newDataOperation.extractNoCancellableResultData()

                // don't override local file if doesn't changed

                if newData == nil {
                    saveFileOperation.result = .success(())
                }
            } catch {
                saveFileOperation.result = .failure(error)
            }
        }

        let completionOperation = ClosureOperation<XcmTransfersType?> {
            // check that file was saved
            _ = try saveFileOperation.extractResultData()

            if let data = try newDataOperation.extractNoCancellableResultData() {
                return try JSONDecoder().decode(XcmTransfersType.self, from: data)
            } else {
                return nil
            }
        }

        completionOperation.addDependency(saveFileOperation)

        let dependencies = [fetchRemoteOperation, newDataOperation, saveFileOperation]

        return CompoundOperationWrapper(targetOperation: completionOperation, dependencies: dependencies)
    }

    override func performSyncUp() {
        guard let localPath = creteLocalFilePath() else {
            completeImmediate(XcmTransfersSyncServiceError.invalidLocalFile(remote: remoteUrl))
            return
        }

        let localWrapper = createLocalWrapper(for: localPath)
        let remoteWrapper = createRemoteWrapper(dependingOn: localWrapper.targetOperation, localPath: localPath)

        localWrapper.targetOperation.completionBlock = { [weak self] in
            do {
                if let transfers = try localWrapper.targetOperation.extractNoCancellableResultData().transfers {
                    self?.notify(with: .success(transfers))
                }
            } catch {
                self?.notify(with: .failure(error))
            }
        }

        remoteWrapper.addDependency(wrapper: localWrapper)

        remoteWrapper.targetOperation.completionBlock = { [weak self] in
            do {
                guard self?.clearOperations() == true else {
                    return
                }

                if let xcmTransfers = try remoteWrapper.targetOperation.extractNoCancellableResultData() {
                    self?.notify(with: .success(xcmTransfers))
                }

                self?.complete(nil)
            } catch {
                self?.notify(with: .failure(error))
            }
        }

        let operations = localWrapper.allOperations + remoteWrapper.allOperations

        self.operations = operations

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    override func stopSyncUp() {
        let operations = self.operations

        self.operations = nil

        operations?.forEach { $0.cancel() }
    }
}
