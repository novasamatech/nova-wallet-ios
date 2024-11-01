import Foundation
import Operation_iOS

final class CrosschainExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId
    let host: CrosschainExchangeHostProtocol

    init(origin: ChainAssetId, destination: ChainAssetId, host: CrosschainExchangeHostProtocol) {
        self.origin = origin
        self.destination = destination
        self.host = host
    }
}

extension CrosschainExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { 1 }

    func quote(
        amount: Balance,
        direction _: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        CompoundOperationWrapper.createWithResult(amount)
    }

    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol {
        CrosschainExchangeAtomicOperation(
            host: host,
            edge: self,
            operationArgs: args
        )
    }

    func appendToOperation(
        _: AssetExchangeAtomicOperationProtocol,
        args _: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        nil
    }
}
