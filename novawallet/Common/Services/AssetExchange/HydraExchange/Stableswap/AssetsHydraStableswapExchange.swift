import Foundation
import Operation_iOS

final class AssetsHydraStableswapExchange {
    let swapFactory: HydraStableswapTokensFactory
    let quoteFactory: HydraStableswapQuoteFactory
    let host: HydraExchangeHostProtocol
    let logger: LoggerProtocol

    init(
        host: HydraExchangeHostProtocol,
        swapFactory: HydraStableswapTokensFactory,
        quoteFactory: HydraStableswapQuoteFactory,
        logger: LoggerProtocol
    ) {
        self.host = host
        self.swapFactory = swapFactory
        self.quoteFactory = quoteFactory
        self.logger = logger
    }
}

extension AssetsHydraStableswapExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let codingFactoryOpertion = host.runtimeService.fetchCoderFactoryOperation()
        let allPoolsWrapper = swapFactory.fetchRemotePools()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let allPools = try allPoolsWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOpertion.extractNoCancellableResultData()

            let allRemoteAssets = Set(allPools.flatMap(\.value) + allPools.keys)

            self.logger.debug("Started processing edges")

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: allRemoteAssets,
                chain: self.host.chain,
                codingFactory: codingFactory
            )

            self.logger.debug("Complete processing edges \(remoteLocalMapping.count)")

            return allPools.flatMap { keyValue in
                let remotePoolAsset = keyValue.key
                let remotePoolAssets = Set(keyValue.value + [remotePoolAsset])

                return remotePoolAssets.flatMap { remoteAssetIn in
                    guard let localAssetIn = remoteLocalMapping[remoteAssetIn] else {
                        self.logger.warning("Skipped remote in \(remoteAssetIn) as no mapping found")
                        return [AnyAssetExchangeEdge]()
                    }

                    let otherAssets = remotePoolAssets.subtracting([remoteAssetIn])

                    return otherAssets.compactMap { remoteAssetOut in
                        guard let localAssetOut = remoteLocalMapping[remoteAssetOut] else {
                            self.logger.warning("Skipped remote out \(remoteAssetOut) as no mapping found")
                            return nil
                        }

                        let edge = HydraStableswapExchangeEdge(
                            origin: localAssetIn,
                            destination: localAssetOut,
                            remoteSwapPair: .init(assetIn: remoteAssetIn, assetOut: remoteAssetOut),
                            poolAsset: remotePoolAsset,
                            host: self.host,
                            quoteFactory: self.quoteFactory
                        )

                        return AnyAssetExchangeEdge(edge)
                    }
                }
            }
        }

        mappingOperation.addDependency(codingFactoryOpertion)
        mappingOperation.addDependency(allPoolsWrapper.targetOperation)

        return allPoolsWrapper
            .insertingHead(operations: [codingFactoryOpertion])
            .insertingTail(operation: mappingOperation)
    }
}
