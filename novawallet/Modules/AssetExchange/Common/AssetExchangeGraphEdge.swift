import Foundation
import Operation_iOS

protocol AssetExchangableGraphEdge: GraphQuotableEdge {
    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol

    func appendToOperation(
        _ currentOperation: AssetExchangeAtomicOperationProtocol,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol?

    func shouldIgnoreFeeRequirement(after predecessor: any AssetExchangableGraphEdge) -> Bool

    func canPayNonNativeFeesInIntermediatePosition() -> Bool

    var type: AssetExchangeEdgeType { get }
}
