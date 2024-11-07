import Foundation

final class AssetExchangeFacade {
    static func createGraphProvider(for params: AssetExchangeGraphProvidingParams) -> AssetsExchangeGraphProviding {
        AssetsExchangeGraphProvider(
            supportedExchangeProviders: [
                CrosschainAssetsExchangeProvider(
                    wallet: params,
                    syncService: XcmTransfersSyncService(
                        remoteUrl: params.config.xcmTransfersURL,
                        operationQueue: params.operationQueue,
                        logger: params.logger
                    ),
                    chainRegistry: params.chainRegistry,
                    signingWrapperFactory: params.signingWrapperFactory,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),

                AssetsHydraExchangeProvider(
                    selectedWallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),

                AssetsHubExchangeProvider(
                    wallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    signingWrapperFactory: params.signingWrapperFactory,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                )
            ],
            operationQueue: params.operationQueue,
            logger: params.logger
        )
    }
}
