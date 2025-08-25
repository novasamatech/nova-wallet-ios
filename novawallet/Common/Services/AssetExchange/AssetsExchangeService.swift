import Foundation
import Operation_iOS

protocol AssetsExchangeServiceProtocol: ApplicationServiceProtocol {
    func subscribeUpdates(for target: AnyObject, notifyingIn queue: DispatchQueue, closure: @escaping () -> Void)
    func unsubscribeUpdates(for target: AnyObject)

    func fetchReachibilityWrapper() -> CompoundOperationWrapper<AssetsExchageGraphReachabilityProtocol>
    func fetchQuoteWrapper(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeQuote>
    func estimateFee(for args: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee>
    func canPayFee(in asset: ChainAsset) -> CompoundOperationWrapper<Bool>

    func submit(
        using estimation: AssetExchangeFee,
        notifyingIn queue: DispatchQueue,
        operationStartClosure: @escaping (Int) -> Void
    ) -> CompoundOperationWrapper<Balance>

    func submitSingleOperationWrapper(
        using estimation: AssetExchangeFee
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel>

    func subscribeRequoteService(
        for target: AnyObject,
        ignoreIfAlreadyAdded: Bool,
        notifyingIn queue: DispatchQueue,
        closure: @escaping () -> Void
    )

    func throttleRequoteService()
}

enum AssetsExchangeServiceError: Error {
    case noRoute
}

final class AssetsExchangeService {
    let exchangesStateMediator: AssetsExchangeStateManaging
    let graphProvider: AssetsExchangeGraphProviding
    let feeSupportProvider: AssetsExchangeFeeSupportProviding
    let pathCostEstimator: AssetsExchangePathCostEstimating
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        graphProvider: AssetsExchangeGraphProviding,
        feeSupportProvider: AssetsExchangeFeeSupportProviding,
        exchangesStateMediator: AssetsExchangeStateManaging,
        pathCostEstimator: AssetsExchangePathCostEstimating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.graphProvider = graphProvider
        self.feeSupportProvider = feeSupportProvider
        self.exchangesStateMediator = exchangesStateMediator
        self.pathCostEstimator = pathCostEstimator
        self.operationQueue = operationQueue
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
                pathCostEstimator: self.pathCostEstimator,
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
        feeSupportProvider.setup()
    }

    func throttle() {
        graphProvider.throttle()
        feeSupportProvider.throttle()
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

    func submitSingleOperationWrapper(
        using estimation: AssetExchangeFee
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel> {
        prepareWrapper {
            $0.createSingleOperationSubmitWrapper(for: estimation)
        }
    }

    func subscribeRequoteService(
        for target: AnyObject,
        ignoreIfAlreadyAdded: Bool,
        notifyingIn queue: DispatchQueue,
        closure: @escaping () -> Void
    ) {
        exchangesStateMediator.subscribeStateChanges(
            target,
            ignoreIfAlreadyAdded: ignoreIfAlreadyAdded,
            notifyingIn: queue,
            closure: closure
        )
    }

    func throttleRequoteService() {
        exchangesStateMediator.throttleStateServicesSynchroniously()
    }

    func canPayFee(in asset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        guard !asset.isUtilityAsset else {
            return CompoundOperationWrapper.createWithResult(true)
        }

        let operation = AsyncClosureOperation<Bool>(operationClosure: { completionClosure in
            self.feeSupportProvider.fetchCurrentState(in: .global()) { state in
                let isFeeSupported = state?.canPayFee(inNonNative: asset.chainAssetId) ?? false
                completionClosure(.success(isFeeSupported))
            }
        })

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
