import Foundation
import Operation_iOS

final class AssetsHydraOmnipoolExchange {
    let chain: ChainModel
    let tokensFactory: HydraOmnipoolTokensFactory
    let quoteFactory: HydraOmnipoolQuoteFactory
    let runtimeService: RuntimeProviderProtocol
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        tokensFactory: HydraOmnipoolTokensFactory,
        quoteFactory: HydraOmnipoolQuoteFactory,
        runtimeService: RuntimeProviderProtocol,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.tokensFactory = tokensFactory
        self.quoteFactory = quoteFactory
        self.runtimeService = runtimeService
        self.logger = logger
    }
}

extension AssetsHydraOmnipoolExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let codingFactoryOpertion = runtimeService.fetchCoderFactoryOperation()
        let remoteAssetsWrapper = tokensFactory.fetchAllRemoteAssets()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let codingFactory = try codingFactoryOpertion.extractNoCancellableResultData()
            let remoteAssets = try remoteAssetsWrapper.targetOperation.extractNoCancellableResultData()

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: remoteAssets,
                chain: self.chain,
                codingFactory: codingFactory,
                failureClosure: { self.logger.error("Token \($0) conversion failed: \($1)") }
            )

            return remoteAssets.flatMap { remoteAssetIn in
                guard let localAssetIn = remoteLocalMapping[remoteAssetIn] else {
                    self.logger.error("Skipped remote in \(remoteAssetIn) as no mapping found")
                    return [AnyAssetExchangeEdge]()
                }

                let otherAssets = remoteAssets.subtracting([remoteAssetIn])

                return otherAssets.compactMap { remoteAssetOut in
                    guard let localAssetOut = remoteLocalMapping[remoteAssetOut] else {
                        self.logger.error("Skipped remote out \(remoteAssetOut) as no mapping found")
                        return nil
                    }

                    let edge = HydraOmnipoolExchangeEdge(
                        origin: localAssetIn,
                        destination: localAssetOut,
                        remoteSwapPair: .init(assetIn: remoteAssetIn, assetOut: remoteAssetOut),
                        quoteFactory: self.quoteFactory
                    )

                    return AnyAssetExchangeEdge(edge)
                }
            }
        }

        mappingOperation.addDependency(remoteAssetsWrapper.targetOperation)
        mappingOperation.addDependency(codingFactoryOpertion)

        return remoteAssetsWrapper
            .insertingHead(operations: [codingFactoryOpertion])
            .insertingTail(operation: mappingOperation)
    }
}
