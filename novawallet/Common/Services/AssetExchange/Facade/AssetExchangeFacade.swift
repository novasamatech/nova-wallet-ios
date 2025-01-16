import Foundation

final class AssetExchangeFacade {
    static func createGraphProvider(
        for params: AssetExchangeGraphProvidingParams,
        feeSupportProvider: AssetsExchangeFeeSupportProviding,
        exchangesStateMediator: AssetsExchangeStateMediating,
        pathCostEstimator: AssetsExchangePathCostEstimating
    ) -> AssetsExchangeGraphProviding {
        let suffiencyProvider = AssetExchangeSufficiencyProvider()

        return AssetsExchangeGraphProvider(
            selectedWallet: params.wallet,
            chainRegistry: params.chainRegistry,
            supportedExchangeProviders: [
                CrosschainAssetsExchangeProvider(
                    wallet: params.wallet,
                    syncService: XcmTransfersSyncService(
                        remoteUrl: params.config.xcmTransfersURL,
                        operationQueue: params.operationQueue,
                        logger: params.logger
                    ),
                    chainRegistry: params.chainRegistry,
                    pathCostEstimator: pathCostEstimator,
                    fungibilityPreservationProvider: AssetFungibilityPreservationProvider.createFromKnownChains(),
                    signingWrapperFactory: params.signingWrapperFactory,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),

                AssetsHydraExchangeProvider(
                    selectedWallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    pathCostEstimator: pathCostEstimator,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    exchangeStateRegistrar: exchangesStateMediator,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),

                AssetsHubExchangeProvider(
                    wallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    pathCostEstimator: pathCostEstimator,
                    signingWrapperFactory: params.signingWrapperFactory,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    exchangeStateRegistrar: exchangesStateMediator,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                )
            ],
            feeSupportProvider: feeSupportProvider,
            suffiencyProvider: suffiencyProvider,
            operationQueue: params.operationQueue,
            logger: params.logger
        )
    }
}
