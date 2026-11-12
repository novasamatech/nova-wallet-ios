import Foundation
import Keystore_iOS

extension SwapSetupViewFactory {
    static func createSwapsTabView(
        initState: SwapSetupInitState,
        assetListObservable: AssetListModelObservable
    ) -> SwapSetupViewProtocol? {
        let state = SwapTokensFlowState(
            assetListObservable: assetListObservable,
            assetExchangeParams: AssetExchangeGraphProvidingParams(
                wallet: SelectedWalletSettings.shared.value
            )
        )

        return createView(
            state: state,
            initState: initState,
            source: .swapsTab,
            placement: .swapsTab,
            swapCompletionClosure: nil
        )
    }

    static func createPrefillResolver() -> SwapSetupPrefillResolving {
        SwapSetupPrefillResolver(
            lastPairStore: SwapLastPairStore(settingsManager: SettingsManager.shared),
            globalConfigProvider: GlobalConfigProvider.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
