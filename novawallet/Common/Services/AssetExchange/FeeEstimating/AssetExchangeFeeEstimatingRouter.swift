import Foundation

final class AssetExchangeFeeEstimatingRouter {
    let graphBasedFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    let dependencies: AssetExchangeFeeEstimatingRouter.Dependencies
    let feeBufferInPercentage: BigRational

    // cache factories to optimize fee calc for multi attempts
    private let conversionCache: InMemoryCache<ChainModel.Id, ExtrinsicCustomFeeEstimatingFactoryProtocol> = .init()

    init(
        graphProxy: AssetQuoteFactoryProtocol,
        dependencies: AssetExchangeFeeEstimatingRouter.Dependencies,
        feeBufferInPercentage: BigRational = AssetExchangeFeeConstants.feeBufferInPercentage
    ) {
        graphBasedFactory = AssetExchangeFeeEstimatingFactory(
            graphProxy: graphProxy,
            operationQueue: dependencies.operationQueue,
            feeBufferInPercentage: feeBufferInPercentage
        )

        self.dependencies = dependencies
        self.feeBufferInPercentage = feeBufferInPercentage
    }
}

private extension AssetExchangeFeeEstimatingRouter {
    func canSwapViaGraph(chainAsset: ChainAsset) -> Bool {
        switch AssetType(rawType: chainAsset.asset.type) {
        case .orml:
            chainAsset.chain.hasSwapHydra
        case .statemine:
            chainAsset.chain.hasSwapHub
        case .none, .equilibrium, .evmNative, .evmAsset:
            false
        }
    }

    func routeViaGraph(chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        dependencies.logger.debug("Using graph factory for chain \(chainAsset.chain.name)")

        return graphBasedFactory.createCustomFeeEstimator(for: chainAsset)
    }

    func routeViaConversion(chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        do {
            let factory: ExtrinsicCustomFeeEstimatingFactoryProtocol
            let chain = chainAsset.chain
            let chainId = chain.chainId

            if let estimatorFactory = conversionCache.fetchValue(for: chainId) {
                factory = estimatorFactory

                dependencies.logger.debug("Using conversion cache for chain \(chain.name)")

            } else {
                let account = try dependencies.wallet.fetchOrError(for: chain.accountRequest())
                let connection = try dependencies.chainRegistry.getConnectionOrError(for: chainId)
                let runtimeProvider = try dependencies.chainRegistry.getRuntimeProviderOrError(for: chainId)

                factory = AssetConversionFeeEstimatingFactory(
                    host: ExtrinsicFeeEstimatorHost(
                        account: account,
                        chain: chain,
                        connection: connection,
                        runtimeProvider: runtimeProvider,
                        userStorageFacade: dependencies.userStorageFacade,
                        substrateStorageFacade: dependencies.substrateStorageFacade,
                        operationQueue: dependencies.operationQueue
                    ),
                    feeBufferInPercentage: feeBufferInPercentage
                )

                conversionCache.store(value: factory, for: chainId)

                dependencies.logger.debug("New factory for chain \(chain.name)")
            }

            return factory.createCustomFeeEstimator(for: chainAsset)
        } catch {
            dependencies.logger.error("Unexpected error: \(error)")

            return nil
        }
    }
}

extension AssetExchangeFeeEstimatingRouter: ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        // swaps might be turned off on the chain
        if canSwapViaGraph(chainAsset: chainAsset) {
            routeViaGraph(chainAsset: chainAsset)
        } else {
            routeViaConversion(chainAsset: chainAsset)
        }
    }
}

extension AssetExchangeFeeEstimatingRouter {
    struct Dependencies {
        let wallet: MetaAccountModel
        let userStorageFacade: StorageFacadeProtocol
        let substrateStorageFacade: StorageFacadeProtocol
        let chainRegistry: ChainRegistryProtocol
        let operationQueue: OperationQueue
        let logger: LoggerProtocol
    }
}
