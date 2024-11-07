import Foundation
import Operation_iOS

protocol AssetsExchangeOperationFactoryProtocol {
    func createQuoteWrapper(args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeRoute?>
    func createFeeWrapper(
        for route: AssetExchangeRoute,
        slippage: BigRational,
        feeAssetId: ChainAssetId?
    ) -> CompoundOperationWrapper<AssetExchangeFee>

    func createExecutionWrapper(for fee: AssetExchangeFee) -> CompoundOperationWrapper<Balance>
}

enum AssetsExchangeOperationFactoryError: Error {
    case noRoute
}

final class AssetsExchangeOperationFactory {
    let graph: AssetsExchangeGraphProtocol
    let operationQueue: OperationQueue
    let maxQuotePaths: Int
    let logger: LoggerProtocol

    init(
        graph: AssetsExchangeGraphProtocol,
        maxQuotePaths: Int = AssetsExchange.maxQuotePaths,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.graph = graph
        self.operationQueue = operationQueue
        self.maxQuotePaths = maxQuotePaths
        self.logger = logger
    }

    private func createOperationArgs(
        for segment: AssetExchangeRouteItem,
        routeDirection: AssetConversion.Direction,
        slippage: BigRational,
        feeAssetId: ChainAssetId?,
        isFirst: Bool
    ) -> AssetExchangeAtomicOperationArgs {
        // on the first segment fee paid in configurable asset and further only in assetIn
        let feeAssetId = isFirst ? feeAssetId : segment.edge.origin

        let segmentDirection: AssetConversion.Direction = if isFirst {
            routeDirection
        } else {
            // we currently can't define buy for non first segment
            .sell
        }

        return .init(
            swapLimit: .init(
                direction: segmentDirection,
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
        feeAssetId: ChainAssetId?
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
}

extension AssetsExchangeOperationFactory: AssetsExchangeOperationFactoryProtocol {
    func createQuoteWrapper(args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
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
                operationQueue: self.operationQueue,
                logger: self.logger
            ).fetchRoute(for: args.amount, direction: args.direction)
        }
    }

    func createFeeWrapper(
        for route: AssetExchangeRoute,
        slippage: BigRational,
        feeAssetId: ChainAssetId?
    ) -> CompoundOperationWrapper<AssetExchangeFee> {
        do {
            let atomicOperations = try prepareAtomicOperations(
                for: route,
                slippage: slippage,
                feeAssetId: feeAssetId
            )

            let feeWrappers = atomicOperations.map { $0.estimateFee() }

            let mappingOperation = ClosureOperation<AssetExchangeFee> {
                let fees = try feeWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

                return AssetExchangeFee(route: route, fees: fees, slippage: slippage, feeAssetId: feeAssetId)
            }

            feeWrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

            let dependencies = feeWrappers.flatMap(\.allOperations)

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
        } catch {
            return .createWithError(error)
        }
    }

    func createExecutionWrapper(for fee: AssetExchangeFee) -> CompoundOperationWrapper<Balance> {
        do {
            guard let firstSegment = fee.route.items.first else {
                return .createWithError(AssetsExchangeServiceError.noRoute)
            }

            let atomicOperations = try prepareAtomicOperations(
                for: fee.route,
                slippage: fee.slippage,
                feeAssetId: fee.feeAssetId
            )

            let executionManager = AssetExchangeExecutionManager(
                operations: atomicOperations,
                operationQueue: operationQueue
            )

            return executionManager.executeSwap(for: firstSegment.amount)
        } catch {
            return .createWithError(error)
        }
    }
}
