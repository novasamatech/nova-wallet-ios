import Foundation
import Operation_iOS

protocol AssetsExchangeOperationFactoryProtocol {
    func createQuoteWrapper(args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeQuote>
    func createFeeWrapper(for args: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee>
    func createExecutionWrapper(for fee: AssetExchangeFee) -> CompoundOperationWrapper<Balance>
}

enum AssetsExchangeOperationFactoryError: Error {
    case noRoute
    case feesOperationsMismatch
}

final class AssetsExchangeOperationFactory {
    let graph: AssetsExchangeGraphProtocol
    let chainRegistry: ChainRegistryProtocol
    let priceStore: AssetExchangePriceStoring
    let operationQueue: OperationQueue
    let maxQuotePaths: Int
    let logger: LoggerProtocol

    init(
        graph: AssetsExchangeGraphProtocol,
        chainRegistry: ChainRegistryProtocol,
        priceStore: AssetExchangePriceStoring,
        maxQuotePaths: Int = AssetsExchange.maxQuotePaths,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.graph = graph
        self.operationQueue = operationQueue
        self.chainRegistry = chainRegistry
        self.priceStore = priceStore
        self.maxQuotePaths = maxQuotePaths
        self.logger = logger
    }

    private func createOperationArgs(
        for segment: AssetExchangeRouteItem,
        routeDirection: AssetConversion.Direction,
        slippage: BigRational,
        feeAssetId: ChainAssetId,
        isFirst: Bool
    ) -> AssetExchangeAtomicOperationArgs {
        // on the first segment fee paid in configurable asset and further only in assetIn
        let feeAssetId = isFirst ? feeAssetId : segment.pathItem.edge.origin

        return .init(
            swapLimit: .init(
                direction: routeDirection,
                amountIn: segment.amountIn(for: routeDirection),
                amountOut: segment.amountOut(for: routeDirection),
                slippage: slippage
            ),
            feeAsset: feeAssetId
        )
    }

    private func prepareAtomicOperations(
        for route: AssetExchangeRoute,
        slippage: BigRational,
        feeAssetId: ChainAssetId
    ) throws -> [AssetExchangeAtomicOperationProtocol] {
        try route.items.reduce([]) { curOperations, segment in
            let args = createOperationArgs(
                for: segment,
                routeDirection: route.direction,
                slippage: slippage,
                feeAssetId: feeAssetId,
                isFirst: curOperations.isEmpty
            )

            if
                let lastOperation = curOperations.last,
                let newOperation = segment.pathItem.edge.appendToOperation(
                    lastOperation,
                    args: args
                ) {
                return curOperations.dropLast() + [newOperation]
            } else {
                let newOperation = try segment.pathItem.edge.beginOperation(for: args)
                return curOperations + [newOperation]
            }
        }
    }

    private func calculateIntermediateFeesInAssetIn(
        for operations: [AssetExchangeAtomicOperationProtocol],
        operationFees: [AssetExchangeOperationFee]
    ) -> CompoundOperationWrapper<Balance> {
        guard operations.count == operationFees.count else {
            return .createWithError(AssetsExchangeOperationFactoryError.feesOperationsMismatch)
        }

        let segmentsWithFee = zip(operations, operationFees)

        let feeWrapper: CompoundOperationWrapper<Balance>? = segmentsWithFee.enumerated().reversed().reduce(
            nil
        ) { prevWrapper, segmentWithFeeIndex in
            let index = segmentWithFeeIndex.offset
            let segment = segmentWithFeeIndex.element.0
            let segmentFee = segmentWithFeeIndex.element.1

            let quoteWrapper: CompoundOperationWrapper<Balance>
            if let prevWrapper {
                let childWrapper = segment.requiredAmountToGetAmountOut {
                    try prevWrapper.targetOperation.extractNoCancellableResultData()
                }

                childWrapper.addDependency(wrapper: prevWrapper)

                quoteWrapper = childWrapper.insertingHead(operations: prevWrapper.allOperations)
            } else {
                quoteWrapper = .createWithResult(0)
            }

            let mappingOperation = ClosureOperation<Balance> {
                let amountIn = try quoteWrapper.targetOperation.extractNoCancellableResultData()

                if index > 0 {
                    let totalFee = try segmentFee.totalEnsuringSubmissionAsset()
                    return amountIn + totalFee
                } else {
                    return amountIn
                }
            }

            mappingOperation.addDependency(quoteWrapper.targetOperation)

            return quoteWrapper.insertingTail(operation: mappingOperation)
        }

        guard let feeWrapper else {
            return .createWithError(AssetsExchangeOperationFactoryError.noRoute)
        }

        return feeWrapper
    }

    private func estimateExecutionTime(
        for operations: [AssetExchangeAtomicOperationProtocol]
    ) -> CompoundOperationWrapper<[TimeInterval]> {
        let wrappers: [CompoundOperationWrapper<TimeInterval>] = operations.map { operation in
            operation.estimatedExecutionTimeWrapper()
        }

        let mappingOperation = ClosureOperation<[TimeInterval]> {
            try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
        }

        wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        let dependecies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependecies)
    }
}

extension AssetsExchangeOperationFactory: AssetsExchangeOperationFactoryProtocol {
    func createQuoteWrapper(args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let wrapper = OperationCombiningService<AssetExchangeRoute?>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let paths = self.graph.fetchPaths(
                from: args.assetIn,
                to: args.assetOut,
                maxTopPaths: self.maxQuotePaths
            )

            guard !paths.isEmpty else {
                return .createWithResult(nil)
            }

            return AssetsExchangeRouteManager(
                possiblePaths: paths,
                chainRegistry: self.chainRegistry,
                priceStore: self.priceStore,
                operationQueue: self.operationQueue,
                logger: self.logger
            ).fetchRoute(for: args.amount, direction: args.direction)
        }

        let mappingOperation = ClosureOperation<AssetExchangeRoute> {
            guard let route = try wrapper.targetOperation.extractNoCancellableResultData() else {
                throw AssetsExchangeOperationFactoryError.noRoute
            }

            return route
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }

    func createFeeWrapper(for args: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee> {
        do {
            let atomicOperations = try prepareAtomicOperations(
                for: args.route,
                slippage: args.slippage,
                feeAssetId: args.feeAssetId
            )

            let feeWrappers = atomicOperations.map { $0.estimateFee() }

            let executionTimeWrapper = estimateExecutionTime(for: atomicOperations)

            let intermediateFeesWrapper = OperationCombiningService<Balance>.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let operationFees = try feeWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

                return self.calculateIntermediateFeesInAssetIn(for: atomicOperations, operationFees: operationFees)
            }

            feeWrappers.forEach { intermediateFeesWrapper.addDependency(wrapper: $0) }

            let mappingOperation = ClosureOperation<AssetExchangeFee> {
                let operationFees = try feeWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

                let intermediateFees = try intermediateFeesWrapper.targetOperation.extractNoCancellableResultData()

                let executionTimes = try executionTimeWrapper.targetOperation.extractNoCancellableResultData()

                return AssetExchangeFee(
                    route: args.route,
                    operations: atomicOperations,
                    operationFees: operationFees,
                    operationExecutionTimes: executionTimes,
                    intermediateFeesInAssetIn: intermediateFees,
                    slippage: args.slippage,
                    feeAssetId: args.feeAssetId,
                    feeAssetPrice: self.priceStore.fetchPrice(for: args.feeAssetId)
                )
            }

            feeWrappers.forEach { mappingOperation.addDependency($0.targetOperation) }
            mappingOperation.addDependency(intermediateFeesWrapper.targetOperation)
            mappingOperation.addDependency(executionTimeWrapper.targetOperation)

            let dependencies = feeWrappers.flatMap(\.allOperations)

            return intermediateFeesWrapper
                .insertingHead(operations: executionTimeWrapper.allOperations)
                .insertingHead(operations: dependencies)
                .insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }

    func createExecutionWrapper(for fee: AssetExchangeFee) -> CompoundOperationWrapper<Balance> {
        let executionManager = AssetExchangeExecutionManager(
            routeDetails: fee,
            operationQueue: operationQueue,
            logger: logger
        )

        let operation = LongrunOperation(longrun: AnyLongrun(longrun: executionManager))

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
