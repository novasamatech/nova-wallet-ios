import Foundation
import Operation_iOS

protocol AssetExchangableGraphEdge: GraphQuotableEdge {
    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol

    func appendToOperation(
        _ currentOperation: AssetExchangeAtomicOperationProtocol,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol?

    func shouldIgnoreFeeRequirement(after predecessor: any AssetExchangableGraphEdge) -> Bool

    func shouldIgnoreDelayedCallRequirement(after predecessor: any AssetExchangableGraphEdge) -> Bool

    func canPayNonNativeFeesInIntermediatePosition() -> Bool

    func requiresOriginKeepAliveOnIntermediatePosition() -> Bool

    func tradeLimitVerdict(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeTradeLimitVerdict>

    var type: AssetExchangeEdgeType { get }

    func beginMetaOperation(for amountIn: Balance, amountOut: Balance) throws -> AssetExchangeMetaOperationProtocol

    func appendToMetaOperation(
        _ currentOperation: AssetExchangeMetaOperationProtocol,
        amountIn: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol?

    func beginOperationPrototype() throws -> AssetExchangeOperationPrototypeProtocol

    func appendToOperationPrototype(
        _ currentPrototype: AssetExchangeOperationPrototypeProtocol
    ) throws -> AssetExchangeOperationPrototypeProtocol?
}

extension AssetExchangableGraphEdge {
    func tradeLimitVerdict(
        amount _: Balance,
        direction _: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeTradeLimitVerdict> {
        .createWithResult(.withinLimit)
    }
}
