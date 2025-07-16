import Foundation
import Operation_iOS

protocol AssetsExchangeOperationFactoryProtocol {
    func createQuoteWrapper(args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeQuote>
    func createFeeWrapper(for args: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee>

    func createExecutionWrapper(
        for fee: AssetExchangeFee,
        notifyingIn queue: DispatchQueue,
        operationStartClosure: @escaping (Int) -> Void
    ) -> CompoundOperationWrapper<Balance>

    func createSingleOperationSubmitWrapper(
        for fee: AssetExchangeFee
    ) -> CompoundOperationWrapper<Void>
}

enum AssetsExchangeOperationFactoryError: Error {
    case noRoute
    case feesOperationsMismatch
    case singleOperationExpected
}

final class AssetsExchangeOperationFactory {
    let graph: AssetsExchangeGraphProtocol
    let operationQueue: OperationQueue
    let pathCostEstimator: AssetsExchangePathCostEstimating
    let maxQuotePaths: Int
    let logger: LoggerProtocol

    init(
        graph: AssetsExchangeGraphProtocol,
        pathCostEstimator: AssetsExchangePathCostEstimating,
        maxQuotePaths: Int = AssetsExchange.maxQuotePaths,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.graph = graph
        self.pathCostEstimator = pathCostEstimator
        self.operationQueue = operationQueue
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
        let feeAssetId = isFirst ? feeAssetId : segment.edge.origin

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
                let newOperation = segment.edge.appendToOperation(
                    lastOperation,
                    args: args
                ) {
                return curOperations.dropLast() + [newOperation]
            } else {
                let newOperation = try segment.edge.beginOperation(for: args)
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
                    let totalFee = try segmentFee.totalEnsuringSubmissionAsset(
                        payerMatcher: .selectedAccount
                    )

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
        using path: AssetExchangeGraphPath
    ) throws -> CompoundOperationWrapper<[TimeInterval]> {
        let prototypes = try createOperationPrototypesFrom(path: path)

        return estimateExecutionTime(for: prototypes)
    }

    private func estimateExecutionTime(
        for operations: [AssetExchangeOperationPrototypeProtocol]
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

    private func createMetaOperationsFrom(route: AssetExchangeRoute) throws -> [AssetExchangeMetaOperationProtocol] {
        try route.items.reduce([]) { curOperations, segment in
            let amountIn = segment.amountIn(for: route.direction)
            let amountOut = segment.amountOut(for: route.direction)

            if
                let lastOperation = curOperations.last,
                let newOperation = try segment.edge.appendToMetaOperation(
                    lastOperation,
                    amountIn: amountIn,
                    amountOut: amountOut
                ) {
                return curOperations.dropLast() + [newOperation]
            } else {
                let newOperation = try segment.edge.beginMetaOperation(for: amountIn, amountOut: amountOut)
                return curOperations + [newOperation]
            }
        }
    }

    private func createOperationPrototypesFrom(
        path: AssetExchangeGraphPath
    ) throws -> [AssetExchangeOperationPrototypeProtocol] {
        try AssetExchangeOperationPrototypeFactory().createOperationPrototypes(
            from: path
        )
    }
}

extension AssetsExchangeOperationFactory: AssetsExchangeOperationFactoryProtocol {
    func createQuoteWrapper(args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeQuote> {
        let routeWrapper = OperationCombiningService<AssetExchangeRoute?>.compoundNonOptionalWrapper(
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

            let routeWrapper = AssetsExchangeRouteManager(
                possiblePaths: paths,
                pathCostEstimator: self.pathCostEstimator,
                operationQueue: self.operationQueue,
                logger: self.logger
            ).fetchRoute(for: args.amount, direction: args.direction)

            return routeWrapper
        }

        let executionTimesWrapper = OperationCombiningService<[TimeInterval]>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            guard let route = try routeWrapper.targetOperation.extractNoCancellableResultData() else {
                throw AssetsExchangeOperationFactoryError.noRoute
            }

            let path = route.items.map(\.edge)

            return try self.estimateExecutionTime(using: path)
        }

        executionTimesWrapper.addDependency(wrapper: routeWrapper)

        let mappingOperation = ClosureOperation<AssetExchangeQuote> {
            guard let route = try routeWrapper.targetOperation.extractNoCancellableResultData() else {
                throw AssetsExchangeOperationFactoryError.noRoute
            }

            let metaOperations = try self.createMetaOperationsFrom(route: route)

            let executionTimes = try executionTimesWrapper.targetOperation.extractNoCancellableResultData()

            return AssetExchangeQuote(route: route, metaOperations: metaOperations, executionTimes: executionTimes)
        }

        mappingOperation.addDependency(routeWrapper.targetOperation)
        mappingOperation.addDependency(executionTimesWrapper.targetOperation)

        return executionTimesWrapper
            .insertingHead(operations: routeWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    func createFeeWrapper(for args: AssetExchangeFeeArgs) -> CompoundOperationWrapper<AssetExchangeFee> {
        do {
            let atomicOperations = try prepareAtomicOperations(
                for: args.route,
                slippage: args.slippage,
                feeAssetId: args.feeAssetId
            )

            let feeWrappers = atomicOperations.map { $0.estimateFee() }

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

                return AssetExchangeFee(
                    route: args.route,
                    operationFees: operationFees,
                    intermediateFeesInAssetIn: intermediateFees,
                    slippage: args.slippage,
                    feeAssetId: args.feeAssetId
                )
            }

            feeWrappers.forEach { mappingOperation.addDependency($0.targetOperation) }
            mappingOperation.addDependency(intermediateFeesWrapper.targetOperation)

            let dependencies = feeWrappers.flatMap(\.allOperations)

            return intermediateFeesWrapper
                .insertingHead(operations: dependencies)
                .insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }

    func createExecutionWrapper(
        for fee: AssetExchangeFee,
        notifyingIn queue: DispatchQueue,
        operationStartClosure: @escaping (Int) -> Void
    ) -> CompoundOperationWrapper<Balance> {
        do {
            let atomicOperations = try prepareAtomicOperations(
                for: fee.route,
                slippage: fee.slippage,
                feeAssetId: fee.feeAssetId
            )

            let executionManager = AssetExchangeExecutionManager(
                operations: atomicOperations,
                fee: fee,
                operationQueue: operationQueue,
                operationStartClosure: operationStartClosure,
                notificationQueue: queue,
                logger: logger
            )

            let operation = LongrunOperation(longrun: AnyLongrun(longrun: executionManager))

            return CompoundOperationWrapper(targetOperation: operation)
        } catch {
            return .createWithError(error)
        }
    }

    func createSingleOperationSubmitWrapper(
        for fee: AssetExchangeFee
    ) -> CompoundOperationWrapper<Void> {
        do {
            let atomicOperations = try prepareAtomicOperations(
                for: fee.route,
                slippage: fee.slippage,
                feeAssetId: fee.feeAssetId
            )

            guard
                atomicOperations.count == 1,
                let atomicOperation = atomicOperations.first else {
                throw AssetsExchangeOperationFactoryError.singleOperationExpected
            }

            let initialAmount = try fee.getInitialAmountIn()

            let swapLimit = atomicOperation.swapLimit.replacingAmountIn(
                initialAmount,
                shouldReplaceBuyWithSell: false
            )

            return atomicOperation.submitWrapper(for: swapLimit)
        } catch {
            return .createWithError(error)
        }
    }
}
