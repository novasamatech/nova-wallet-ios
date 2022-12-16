import Foundation
import RobinHood

final class OperationManagerFacade {
    static let sharedDefaultQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 30
        return queue
    }()

    static let runtimeBuildingQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 15
        return operationQueue
    }()

    static let runtimeSyncQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 30
        return operationQueue
    }()

    static let fileDownloadQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 15
        return operationQueue
    }()

    static let assetsSyncQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 30
        return operationQueue
    }()

    static let assetsRepositoryQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 30
        return operationQueue
    }()

    static let nftQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 15
        return operationQueue
    }()

    static let sharedManager = OperationManager(operationQueue: sharedDefaultQueue)
}
