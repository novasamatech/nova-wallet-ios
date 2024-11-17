import Foundation

final class AssetExchangeFacade {
    static func createGraphProvider(
        for params: AssetExchangeGraphProvidingParams,
        priceStore: AssetExchangePriceStoring
    ) -> AssetsExchangeGraphProviding {
        let feeSupportProvider = AssetExchangeFeeSupportProvider(
            chainRegistry: params.chainRegistry,
            operationQueue: params.operationQueue,
            logger: params.logger
        )

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
                    priceStore: priceStore,
                    signingWrapperFactory: params.signingWrapperFactory,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),

                AssetsHydraExchangeProvider(
                    selectedWallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    priceStore: priceStore,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),

                AssetsHubExchangeProvider(
                    wallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    priceStore: priceStore,
                    signingWrapperFactory: params.signingWrapperFactory,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
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
