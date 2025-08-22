import Foundation
import Operation_iOS

final class AssetsHydraAaveExchange {
    let host: HydraExchangeHostProtocol
    let apiOperationFactory: HydraAaveTradeExecutorFactoryProtocol
    let quoteFactory: HydraAaveSwapQuoteFactory

    init(
        host: HydraExchangeHostProtocol,
        apiOperationFactory: HydraAaveTradeExecutorFactoryProtocol,
        quoteFactory: HydraAaveSwapQuoteFactory
    ) {
        self.host = host
        self.apiOperationFactory = apiOperationFactory
        self.quoteFactory = quoteFactory
    }
}

private extension AssetsHydraAaveExchange {
    func createEdgesWrapper(
        dependingOn pairsOperation: BaseOperation<[HydraAave.TradePair]>
    ) -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let mapperOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let remotePairs = try pairsOperation.extractNoCancellableResultData()

            let allRemoteAssets = remotePairs.reduce(into: Set<HydraDx.AssetId>()) { accum, pair in
                accum.insert(pair.asset1)
                accum.insert(pair.asset2)
            }

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: allRemoteAssets,
                chain: self.host.chain,
                codingFactory: codingFactory,
                failureClosure: { self.host.logger.warning("Token \($0) conversion failed: \($1)") }
            )

            let edges: [AnyAssetExchangeEdge] = remotePairs.flatMap { pair in
                guard
                    let localAsset1 = remoteLocalMapping[pair.asset1],
                    let localAsset2 = remoteLocalMapping[pair.asset2] else {
                    return [AnyAssetExchangeEdge]()
                }

                let edge1 = HydraAaveExchangeEdge(
                    origin: localAsset1,
                    destination: localAsset2,
                    remoteSwapPair: .init(assetIn: pair.asset1, assetOut: pair.asset2),
                    host: self.host,
                    quoteFactory: self.quoteFactory
                )

                let edge2 = HydraAaveExchangeEdge(
                    origin: localAsset2,
                    destination: localAsset1,
                    remoteSwapPair: .init(assetIn: pair.asset2, assetOut: pair.asset1),
                    host: self.host,
                    quoteFactory: self.quoteFactory
                )

                return [AnyAssetExchangeEdge(edge1), AnyAssetExchangeEdge(edge2)]
            }

            return edges
        }

        mapperOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(targetOperation: mapperOperation, dependencies: [codingFactoryOperation])
    }
}

extension AssetsHydraAaveExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let allPairsWrapper = apiOperationFactory.createAaveTradePairs()

        let edgesWrapper = createEdgesWrapper(dependingOn: allPairsWrapper.targetOperation)

        edgesWrapper.addDependency(wrapper: allPairsWrapper)

        return edgesWrapper.insertingHead(operations: allPairsWrapper.allOperations)
    }
}
