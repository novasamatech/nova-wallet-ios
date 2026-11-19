import Foundation
import Keystore_iOS
import NovaAnalytics

extension SwapSetupViewFactory {
    static func createSwapsTabView(
        initState: SwapSetupInitState,
        source: SwapSource,
        assetListObservable: AssetListModelObservable,
        formHost: SwapsTabFlowHosting & SwapSetupModuleInputOwnerProtocol
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
            source: source,
            placement: .swapsTab,
            flowHandler: SwapExecutionTabFlowHandler(
                formHost: formHost,
                lastPairStore: SwapLastPairStore(settingsManager: SettingsManager.shared)
            ),
            inputOwner: formHost
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
