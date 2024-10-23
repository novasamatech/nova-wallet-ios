import Foundation
import Operation_iOS
import SubstrateSdk

final class AssetsHubExchange {
    let swapFactory: AssetHubSwapOperationFactoryProtocol

    init(
        chain: ChainModel,
        runtimeService: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        swapFactory = AssetHubSwapOperationFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )
    }

    private func availableDirectSwapConnections(
        using swapFactory: AssetHubSwapOperationFactoryProtocol
    ) -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let connectionsWrapper = swapFactory.availableDirections()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let connections = try connectionsWrapper.targetOperation.extractNoCancellableResultData()

            return connections.flatMap { keyValue in
                let origin = keyValue.key

                return keyValue.value.map { destination in
                    AssetHubExchangeEdge(origin: origin, destination: destination, quoteFactory: swapFactory)
                }
            }
        }

        mappingOperation.addDependency(connectionsWrapper.targetOperation)

        return connectionsWrapper.insertingTail(operation: mappingOperation)
    }
}

extension AssetsHubExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        availableDirectSwapConnections(using: swapFactory)
    }
}
