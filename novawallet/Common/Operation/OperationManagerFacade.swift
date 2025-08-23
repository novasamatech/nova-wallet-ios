import Foundation
import Operation_iOS

final class OperationManagerFacade {
    static let sharedDefaultQueue: OperationQueue = {
        let queue = OperationQueue()
        return queue
    }()

    static let runtimeBuildingQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        return operationQueue
    }()

    static let runtimeSyncQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        return operationQueue
    }()

    static let fileDownloadQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        return operationQueue
    }()

    static let assetsSyncQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        return operationQueue
    }()

    static let assetsRepositoryQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        return operationQueue
    }()

    static let nftQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        return operationQueue
    }()

    static let cloudBackupQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        return operationQueue
    }()

    static let pendingMultisigQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        return operationQueue
    }()

    static let sharedManager = OperationManager(operationQueue: sharedDefaultQueue)
}
