import Foundation
import Operation_iOS

final class AssetsHydraStableswapExchange {
    let swapFactory: HydraStableswapTokensFactory
    let quoteFactory: HydraStableswapQuoteFactory
    let chain: ChainModel
    let runtimeService: RuntimeProviderProtocol
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        swapFactory: HydraStableswapTokensFactory,
        quoteFactory: HydraStableswapQuoteFactory,
        runtimeService: RuntimeProviderProtocol,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.swapFactory = swapFactory
        self.quoteFactory = quoteFactory
        self.runtimeService = runtimeService
        self.logger = logger
    }
}

extension AssetsHydraStableswapExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let codingFactoryOpertion = runtimeService.fetchCoderFactoryOperation()
        let allPoolsWrapper = swapFactory.fetchRemotePools()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let allPools = try allPoolsWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOpertion.extractNoCancellableResultData()

            let allRemoteAssets = Set(allPools.flatMap(\.value) + allPools.keys)

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: allRemoteAssets,
                chain: self.chain,
                codingFactory: codingFactory,
                failureClosure: { self.logger.error("Token \($0) conversion failed: \($1)") }
            )

            return allPools.flatMap { keyValue in
                let remotePoolAsset = keyValue.key
                let remotePoolAssets = Set(keyValue.value + [remotePoolAsset])

                return remotePoolAssets.flatMap { remoteAssetIn in
                    guard let localAssetIn = remoteLocalMapping[remoteAssetIn] else {
                        self.logger.error("Skipped remote in \(remoteAssetIn) as no mapping found")
                        return [AnyAssetExchangeEdge]()
                    }

                    let otherAssets = remotePoolAssets.subtracting([remoteAssetIn])

                    return otherAssets.compactMap { remoteAssetOut in
                        guard let localAssetOut = remoteLocalMapping[remoteAssetOut] else {
                            self.logger.error("Skipped remote out \(remoteAssetOut) as no mapping found")
                            return nil
                        }

                        let edge = AssetsHydraStableswapExchangeEdge(
                            origin: localAssetIn,
                            destination: localAssetOut,
                            remoteSwapPair: .init(assetIn: remoteAssetIn, assetOut: remoteAssetOut),
                            poolAsset: remotePoolAsset,
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
