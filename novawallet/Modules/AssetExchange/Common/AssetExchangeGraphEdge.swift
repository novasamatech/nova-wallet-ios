import Foundation
import Operation_iOS

protocol AssetExchangableGraphEdge: GraphQuotableEdge {
    func beginOperation(for args: AssetExchangeAtomicOperationArgs) -> AssetExchangeAtomicOperationProtocol
    
    func appendToOperation(
        _ currentOperation: AssetExchangeAtomicOperationProtocol,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol?
}
