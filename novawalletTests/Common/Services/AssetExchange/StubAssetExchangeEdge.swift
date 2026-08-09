import Foundation
@testable import novawallet
import Operation_iOS

enum StubAssetExchangeEdgeError: Error {
    case notSupported
}

final class StubAssetExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId
    let type: AssetExchangeEdgeType
    let chain: ChainModel
    let quoteClosure: (Balance, AssetConversion.Direction) -> Balance

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        type: AssetExchangeEdgeType,
        chain: ChainModel,
        quoteClosure: @escaping (Balance, AssetConversion.Direction) -> Balance = { amount, _ in amount }
    ) {
        self.origin = origin
        self.destination = destination
        self.type = type
        self.chain = chain
        self.quoteClosure = quoteClosure
    }
}

extension StubAssetExchangeEdge: AssetExchangableGraphEdge {
    func quote(amount: Balance, direction: AssetConversion.Direction) -> CompoundOperationWrapper<Balance> {
        .createWithResult(quoteClosure(amount, direction))
    }

    func addingWeight(to currentWeight: Int, predecessor _: AnyGraphEdgeProtocol?) -> Int {
        currentWeight + 1
    }

    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol {
        StubAtomicOperation(edges: [self], args: args)
    }

    func appendToOperation(
        _ operation: AssetExchangeAtomicOperationProtocol,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        guard
            type == .hydraSwap,
            let stubOperation = operation as? StubAtomicOperation,
            let lastEdge = stubOperation.edges.last,
            lastEdge.type == .hydraSwap,
            origin == lastEdge.destination else {
            return nil
        }

        return StubAtomicOperation(
            edges: stubOperation.edges + [self],
            args: stubOperation.args.extendingForTest(with: args)
        )
    }

    func shouldIgnoreFeeRequirement(after predecessor: any AssetExchangableGraphEdge) -> Bool {
        type == predecessor.type
    }

    func shouldIgnoreDelayedCallRequirement(after predecessor: any AssetExchangableGraphEdge) -> Bool {
        type == predecessor.type
    }

    func canPayNonNativeFeesInIntermediatePosition() -> Bool {
        true
    }

    func requiresOriginKeepAliveOnIntermediatePosition() -> Bool {
        false
    }

    func beginMetaOperation(for amountIn: Balance, amountOut: Balance) throws -> AssetExchangeMetaOperationProtocol {
        StubMetaOperation(
            assetIn: try chain.chainAssetOrError(for: origin.assetId),
            assetOut: try chain.chainAssetOrError(for: destination.assetId),
            amountIn: amountIn,
            amountOut: amountOut,
            edgeType: type
        )
    }

    func appendToMetaOperation(
        _ currentOperation: AssetExchangeMetaOperationProtocol,
        amountIn _: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol? {
        guard
            type == .hydraSwap,
            let stubOperation = currentOperation as? StubMetaOperation,
            stubOperation.edgeType == .hydraSwap,
            currentOperation.assetOut.chainAssetId == origin else {
            return nil
        }

        return StubMetaOperation(
            assetIn: currentOperation.assetIn,
            assetOut: try chain.chainAssetOrError(for: destination.assetId),
            amountIn: currentOperation.amountIn,
            amountOut: amountOut,
            edgeType: type
        )
    }

    func beginOperationPrototype() throws -> AssetExchangeOperationPrototypeProtocol {
        StubOperationPrototype(
            assetIn: try chain.chainAssetOrError(for: origin.assetId),
            assetOut: try chain.chainAssetOrError(for: destination.assetId),
            edgeType: type
        )
    }

    func appendToOperationPrototype(
        _ currentPrototype: AssetExchangeOperationPrototypeProtocol
    ) throws -> AssetExchangeOperationPrototypeProtocol? {
        guard
            type == .hydraSwap,
            let stubPrototype = currentPrototype as? StubOperationPrototype,
            stubPrototype.edgeType == .hydraSwap,
            currentPrototype.assetOut.chainAssetId == origin else {
            return nil
        }

        return StubOperationPrototype(
            assetIn: currentPrototype.assetIn,
            assetOut: try chain.chainAssetOrError(for: destination.assetId),
            edgeType: type
        )
    }
}

final class StubAtomicOperation: AssetExchangeAtomicOperationProtocol {
    let edges: [StubAssetExchangeEdge]
    let args: AssetExchangeAtomicOperationArgs

    init(edges: [StubAssetExchangeEdge], args: AssetExchangeAtomicOperationArgs) {
        self.edges = edges
        self.args = args
    }

    var swapLimit: AssetExchangeSwapLimit { args.swapLimit }

    func executeWrapper(for _: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Balance> {
        .createWithError(StubAssetExchangeEdgeError.notSupported)
    }

    func submitWrapper(
        for _: AssetExchangeSwapLimit
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel> {
        .createWithError(StubAssetExchangeEdgeError.notSupported)
    }

    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee> {
        .createWithError(StubAssetExchangeEdgeError.notSupported)
    }

    func requiredAmountToGetAmountOut(
        _: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
        .createWithError(StubAssetExchangeEdgeError.notSupported)
    }
}

final class StubMetaOperation: AssetExchangeBaseMetaOperation {
    let edgeType: AssetExchangeEdgeType

    init(
        assetIn: ChainAsset,
        assetOut: ChainAsset,
        amountIn: Balance,
        amountOut: Balance,
        edgeType: AssetExchangeEdgeType = .hydraSwap
    ) {
        self.edgeType = edgeType

        super.init(assetIn: assetIn, assetOut: assetOut, amountIn: amountIn, amountOut: amountOut)
    }
}

extension StubMetaOperation: AssetExchangeMetaOperationProtocol {
    var label: AssetExchangeMetaOperationLabel { .swap }
    var requiresOriginAccountKeepAlive: Bool { false }
}

final class StubOperationPrototype: AssetExchangeBaseOperationPrototype {
    let edgeType: AssetExchangeEdgeType

    init(assetIn: ChainAsset, assetOut: ChainAsset, edgeType: AssetExchangeEdgeType) {
        self.edgeType = edgeType

        super.init(assetIn: assetIn, assetOut: assetOut)
    }
}

extension StubOperationPrototype: AssetExchangeOperationPrototypeProtocol {
    func estimatedCostInUsdt(using _: AssetExchageUsdtConverting) throws -> Decimal {
        0
    }

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval> {
        .createWithResult(0)
    }
}

extension AssetExchangeAtomicOperationArgs {
    func extendingForTest(with other: AssetExchangeAtomicOperationArgs) -> AssetExchangeAtomicOperationArgs {
        .init(
            swapLimit: .init(
                direction: swapLimit.direction,
                amountIn: swapLimit.amountIn,
                amountOut: other.swapLimit.amountOut,
                slippage: other.swapLimit.slippage
            ),
            feeAsset: feeAsset,
            commission: other.commission ?? commission
        )
    }
}
