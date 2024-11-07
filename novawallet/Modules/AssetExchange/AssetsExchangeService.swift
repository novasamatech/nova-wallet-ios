import Foundation
import Operation_iOS

protocol AssetsExchangeServiceProtocol: ApplicationServiceProtocol {
    func subscribeUpdates(for target: AnyObject, notifyingIn queue: DispatchQueue, closure: @escaping () -> Void)
    func unsubscribeUpdates(for target: AnyObject)
    
    func fetchReachibilityWrapper() -> CompoundOperationWrapper<AssetsExchageGraphReachabilityProtocol>
}

enum AssetsExchangeServiceError: Error {
    case noRoute
}

final class AssetsExchangeService {
    let graphProvider: AssetsExchangeGraphProviding
    let operationQueue: OperationQueue

    init(
        graphProvider: AssetsExchangeGraphProviding,
        operationQueue: OperationQueue
    ) {
        self.graphProvider = graphProvider
        self.operationQueue = operationQueue
    }
}

extension AssetsExchangeService: AssetsExchangeServiceProtocol {
    func setup() {
        graphProvider.setup()
    }
    
    func throttle() {
        graphProvider.throttle()
    }
    
    func subscribeUpdates(for target: AnyObject, notifyingIn queue: DispatchQueue, closure: @escaping () -> Void) {
        graphProvider.subscribeGraph(
            target,
            notifyingIn: queue
        ) {
            closure()
        }
    }
    
    func unsubscribeUpdates(for target: AnyObject) {
        graphProvider.unsubscribeGraph(target)
    }
    
    func fetchReachibilityWrapper() -> CompoundOperationWrapper<AssetsExchageGraphReachabilityProtocol> {
        let graphWrapper = graphProvider.asyncWaitGraphWrapper(using: operationQueue)
        
        let directionsOperation = ClosureOperation<AssetsExchageGraphReachabilityProtocol> {
            let graph = try graphWrapper.targetOperation.extractNoCancellableResultData()
            
            return graph.fetchReachability()
        }
        
        directionsOperation.addDependency(graphWrapper.targetOperation)
        
        return graphWrapper.insertingTail(operation: directionsOperation)
    }
}
