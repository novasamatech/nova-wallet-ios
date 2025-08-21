import Foundation
import Operation_iOS

final class AssetsHydraOmnipoolExchange {
    let tokensFactory: HydraOmnipoolTokensFactory
    let quoteFactory: HydraOmnipoolQuoteFactory
    let host: HydraExchangeHostProtocol
    let logger: LoggerProtocol

    init(
        host: HydraExchangeHostProtocol,
        tokensFactory: HydraOmnipoolTokensFactory,
        quoteFactory: HydraOmnipoolQuoteFactory,
        logger: LoggerProtocol
    ) {
        self.tokensFactory = tokensFactory
        self.quoteFactory = quoteFactory
        self.host = host
        self.logger = logger
    }
}

extension AssetsHydraOmnipoolExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let codingFactoryOpertion = host.runtimeService.fetchCoderFactoryOperation()
        let remoteAssetsWrapper = tokensFactory.fetchAllRemoteAssets()

        let mappingOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let codingFactory = try codingFactoryOpertion.extractNoCancellableResultData()
            let remoteAssets = try remoteAssetsWrapper.targetOperation.extractNoCancellableResultData()

            self.logger.debug("Start processing edges")

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: remoteAssets,
                chain: self.host.chain,
                codingFactory: codingFactory,
                failureClosure: { self.logger.warning("Token \($0) conversion failed: \($1)") }
            )

            self.logger.debug("Complete processing edges \(remoteLocalMapping.count)")

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
                        host: self.host,
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
