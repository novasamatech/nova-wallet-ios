import Foundation
import Operation_iOS

final class CrosschainAssetsExchange {
    let host: CrosschainExchangeHostProtocol
    let featureFactoryFacade: XcmTransferFeaturesFacadeProtocol

    init(host: CrosschainExchangeHostProtocol) {
        self.host = host

        featureFactoryFacade = XcmTransferFeaturesFacade(
            chainRegistry: host.chainRegistry,
            operationQueue: host.operationQueue
        )
    }
}

private extension CrosschainAssetsExchange {
    typealias XcmFeatureFactories = [ChainModel.Id: XcmTransferFeaturesFactoryProtocol]

    func createExchange(
        from origin: ChainAssetId,
        destination: ChainAssetId,
        featuresFactory: XcmTransferFeaturesFactoryProtocol
    ) -> CrosschainExchangeEdge? {
        do {
            let originChain = try host.chainRegistry.getChainOrError(for: origin.chainId)
            let originChainAsset = try originChain.chainAssetOrError(for: origin.assetId)
            let destinationChain = try host.chainRegistry.getChainOrError(for: destination.chainId)

            let metadata = try host.xcmTransfers.getTransferMetadata(
                for: originChainAsset,
                destinationChain: destinationChain
            )

            let features = featuresFactory.createFeatures(for: metadata)

            return CrosschainExchangeEdge(
                origin: origin,
                destination: destination,
                host: host,
                features: features
            )
        } catch {
            host.logger.error("Unexpected error \(error)")
            return nil
        }
    }

    func createFeaturesFactoriesWrapper() -> CompoundOperationWrapper<XcmFeatureFactories> {
        let allChainsList = host.xcmTransfers.getAllTransfers()
            .keys
            .map(\.chainId)
            .distinct()

        let allWrappers = allChainsList.map { chainId in
            if host.xcmTransfers.hasDynamicConfig(for: chainId) {
                return featureFactoryFacade.createFeaturesFactoryWrapper(for: chainId)
            } else {
                return .createWithResult(XcmTransferFeaturesFactory(hasXcmPaymentApi: false))
            }
        }

        let mappingOperation = ClosureOperation<XcmFeatureFactories> {
            let factories: [XcmTransferFeaturesFactoryProtocol?] = allWrappers.map {
                do {
                    return try $0.targetOperation.extractNoCancellableResultData()
                } catch {
                    self.host.logger.error("Unexpected error \(error)")
                    return nil
                }
            }

            return zip(allChainsList, factories).reduce(into: XcmFeatureFactories()) {
                $0[$1.0] = $1.1
            }
        }

        let dependencies = allWrappers.flatMap(\.allOperations)

        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension CrosschainAssetsExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let featuresFactoriesWrapper = createFeaturesFactoriesWrapper()

        let mapOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let factories = try featuresFactoriesWrapper.targetOperation.extractNoCancellableResultData()
            let edges = self.host.xcmTransfers.getAllTransfers()
                .map { keyValue in
                    guard let featuresFactory = factories[keyValue.key.chainId] else {
                        return [any AssetExchangableGraphEdge]()
                    }

                    return keyValue.value.compactMap { destinationAssetId in
                        self.createExchange(
                            from: keyValue.key,
                            destination: destinationAssetId,
                            featuresFactory: featuresFactory
                        )
                    }
                }
                .flatMap { $0 }
            return edges
        }

        mapOperation.addDependency(featuresFactoriesWrapper.targetOperation)

        return featuresFactoriesWrapper.insertingTail(operation: mapOperation)
    }
}
