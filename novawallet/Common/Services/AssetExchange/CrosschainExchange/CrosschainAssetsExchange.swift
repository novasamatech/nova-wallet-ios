import Foundation
import Operation_iOS

final class CrosschainAssetsExchange {
    let host: CrosschainExchangeHostProtocol

    init(host: CrosschainExchangeHostProtocol) {
        self.host = host
    }

    private func createExchange(from origin: ChainAssetId, destination: ChainAssetId) -> CrosschainExchangeEdge {
        CrosschainExchangeEdge(origin: origin, destination: destination, host: host)
    }
}

extension CrosschainAssetsExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let operation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            self.host.xcmTransfers.getAllTransfers()
                .map { keyValue in
                    keyValue.value.map { destinationAssetId in
                        self.createExchange(
                            from: keyValue.key,
                            destination: destinationAssetId
                        )
                    }
                }
                .flatMap { $0 }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
