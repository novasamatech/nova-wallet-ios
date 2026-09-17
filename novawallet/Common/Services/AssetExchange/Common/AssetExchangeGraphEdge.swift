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

    /// The pool the edge trades through, when the route must not enter it twice
    var poolId: AssetExchangePoolId? { get }

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
