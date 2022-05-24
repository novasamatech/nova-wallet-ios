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
        operationQueue.maxConcurrentOperationCount = 10
        return operationQueue
    }()

    static let runtimeSyncQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 8
        return operationQueue
    }()

    static let fileDownloadQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 10
        return operationQueue
    }()

    static let assetsQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 20
        return operationQueue
    }()

    static let sharedManager = OperationManager(operationQueue: sharedDefaultQueue)
}
