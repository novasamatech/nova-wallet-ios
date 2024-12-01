import Foundation
import Operation_iOS

protocol AssetsExchangeServiceProtocol: ApplicationServiceProtocol {
    func subscribeUpdates(for target: AnyObject, notifyingIn queue: DispatchQueue, closure: @escaping () -> Void)
    func unsubscribeUpdates(for target: AnyObject)

    func fetchReachibilityWrapper() -> CompoundOperationWrapper<AssetsExchageGraphReachabilityProtocol>
    func fetchQuoteWrapper(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeQuote>
    func estimateFee(for args: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee>

    func submit(
        using estimation: AssetExchangeFee,
        notifyingIn queue: DispatchQueue,
        operationStartClosure: @escaping (Int) -> Void
    ) -> CompoundOperationWrapper<Balance>
}

enum AssetsExchangeServiceError: Error {
    case noRoute
}

final class AssetsExchangeService {
    let graphProvider: AssetsExchangeGraphProviding
    let chainRegistry: ChainRegistryProtocol
    let priceStore: AssetExchangePriceStoring
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        graphProvider: AssetsExchangeGraphProviding,
        chainRegistry: ChainRegistryProtocol,
        priceStore: AssetExchangePriceStoring,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.graphProvider = graphProvider
        self.operationQueue = operationQueue
        self.chainRegistry = chainRegistry
        self.priceStore = priceStore
        self.logger = logger
    }

    private func prepareWrapper<T>(
        for factoryClosure: @escaping (AssetsExchangeOperationFactoryProtocol) -> CompoundOperationWrapper<T>
    ) -> CompoundOperationWrapper<T> {
        let graphWrapper = graphProvider.asyncWaitGraphWrapper()

        let targetWrapper = OperationCombiningService<T>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let graph = try graphWrapper.targetOperation.extractNoCancellableResultData()

            let operationFactory = AssetsExchangeOperationFactory(
                graph: graph,
                chainRegistry: self.chainRegistry,
                priceStore: self.priceStore,
                operationQueue: self.operationQueue,
                logger: self.logger
            )

            return factoryClosure(operationFactory)
        }

        targetWrapper.addDependency(wrapper: graphWrapper)

        return targetWrapper.insertingHead(operations: graphWrapper.allOperations)
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
        ) { _ in
            closure()
        }
    }

    func unsubscribeUpdates(for target: AnyObject) {
        graphProvider.unsubscribeGraph(target)
    }

    func fetchReachibilityWrapper() -> CompoundOperationWrapper<AssetsExchageGraphReachabilityProtocol> {
        let graphWrapper = graphProvider.asyncWaitGraphWrapper()

        let directionsOperation = ClosureOperation<AssetsExchageGraphReachabilityProtocol> {
            let graph = try graphWrapper.targetOperation.extractNoCancellableResultData()

            return graph.fetchReachability()
        }

        directionsOperation.addDependency(graphWrapper.targetOperation)

        return graphWrapper.insertingTail(operation: directionsOperation)
    }

    func fetchQuoteWrapper(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeQuote> {
        prepareWrapper { operationFactory in
            operationFactory.createQuoteWrapper(args: args)
        }
    }

    func estimateFee(for args: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee> {
        prepareWrapper { $0.createFeeWrapper(for: args) }
    }

    func submit(
        using estimation: AssetExchangeFee,
        notifyingIn queue: DispatchQueue,
        operationStartClosure: @escaping (Int) -> Void
    ) -> CompoundOperationWrapper<Balance> {
        prepareWrapper {
            $0.createExecutionWrapper(
                for: estimation,
                notifyingIn: queue,
                operationStartClosure: operationStartClosure
            )
        }
    }
}
