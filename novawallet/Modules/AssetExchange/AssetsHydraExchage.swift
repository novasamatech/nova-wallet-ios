import Foundation
import Operation_iOS

extension HydraPoolTokensFactoryProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let connectionsWrapper = availableDirections()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let connections = try connectionsWrapper.targetOperation.extractNoCancellableResultData()

            return connections.flatMap { keyValue in
                let origin = keyValue.key

                return keyValue.value.map { HydraExchangeEdge(origin: origin, destination: $0) }
            }
        }

        mappingOperation.addDependency(connectionsWrapper.targetOperation)

        return connectionsWrapper.insertingTail(operation: mappingOperation)
    }
}

typealias AssetsHydraOmnipoolExchange = HydraOmnipoolTokensFactory

extension AssetsHydraOmnipoolExchange: AssetsExchangeProtocol {}

typealias AssetsHydraStableSwapExchange = HydraStableSwapsTokensFactory

extension AssetsHydraStableSwapExchange: AssetsExchangeProtocol {}

typealias AssetsHydraXYKExchange = HydraXYKPoolTokensFactory

extension AssetsHydraXYKExchange: AssetsExchangeProtocol {}
