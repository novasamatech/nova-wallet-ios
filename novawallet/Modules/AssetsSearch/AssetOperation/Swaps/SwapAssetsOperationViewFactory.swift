import Foundation
import Keystore_iOS
import Foundation_iOS

enum SwapAssetsOperationViewFactory {
    static func createSelectPayTokenView(
        for stateObservable: AssetListModelObservable,
        selectionModel: SwapAssetSelectionModel,
        selectClosureStrategy: SubmoduleNavigationStrategy = .callbackBeforeDismissal,
        selectClosure: @escaping SwapAssetSelectionClosure
    ) -> AssetsSearchViewProtocol? {
        let state = SwapTokensFlowState(
            assetListObservable: stateObservable,
            assetExchangeParams: AssetExchangeGraphProvidingParams(
                wallet: SelectedWalletSettings.shared.value
            )
        )

        return createSelectPayTokenViewWithState(
            state,
            selectionModel: selectionModel,
            selectClosureStrategy: selectClosureStrategy,
            selectClosure: selectClosure
        )
    }

    static func createSelectPayTokenViewWithState(
        _ state: SwapTokensFlowStateProtocol,
        selectionModel: SwapAssetSelectionModel,
        selectClosureStrategy: SubmoduleNavigationStrategy = .callbackBeforeDismissal,
        selectClosure: @escaping SwapAssetSelectionClosure
    ) -> AssetsSearchViewProtocol? {
        let title: LocalizableResource<String> = .init {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsPayTokenSelectionTitle()
        }

        return createView(
            using: state,
            selectionModel: selectionModel,
            title: title,
            selectClosureStrategy: selectClosureStrategy,
            selectClosure: selectClosure
        )
    }

    static func createSelectReceiveTokenView(
        for stateObservable: AssetListModelObservable,
        selectionModel: SwapAssetSelectionModel,
        selectClosureStrategy: SubmoduleNavigationStrategy = .callbackBeforeDismissal,
        selectClosure: @escaping SwapAssetSelectionClosure
    ) -> AssetsSearchViewProtocol? {
        let state = SwapTokensFlowState(
            assetListObservable: stateObservable,
            assetExchangeParams: AssetExchangeGraphProvidingParams(
                wallet: SelectedWalletSettings.shared.value
            )
        )

        return createSelectReceiveTokenViewWithState(
            state,
            selectionModel: selectionModel,
            selectClosureStrategy: selectClosureStrategy,
            selectClosure: selectClosure
        )
    }

    static func createSelectReceiveTokenViewWithState(
        _ state: SwapTokensFlowStateProtocol,
        selectionModel: SwapAssetSelectionModel,
        selectClosureStrategy: SubmoduleNavigationStrategy = .callbackBeforeDismissal,
        selectClosure: @escaping SwapAssetSelectionClosure
    ) -> AssetsSearchViewProtocol? {
        let title: LocalizableResource<String> = .init {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsReceiveTokenSelectionTitle()
        }

        return createView(
            using: state,
            selectionModel: selectionModel,
            title: title,
            selectClosureStrategy: selectClosureStrategy,
            selectClosure: selectClosure
        )
    }

    static func createView(
        using state: SwapTokensFlowStateProtocol,
        selectionModel: SwapAssetSelectionModel,
        title: LocalizableResource<String>,
        selectClosureStrategy: SubmoduleNavigationStrategy,
        selectClosure: @escaping SwapAssetSelectionClosure
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListAssetViewModelFactory(
            chainAssetViewModelFactory: ChainAssetViewModelFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            currencyManager: currencyManager
        )

        guard let presenter = createPresenter(
            state: state,
            viewModelFactory: viewModelFactory,
            selectionModel: selectionModel,
            selectClosureStrategy: selectClosureStrategy,
            selectClosure: selectClosure
        ) else {
            return nil
        }

        let view = SwapAssetsOperationViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: [.viewDidAppear]),
            createViewClosure: { SwapAssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    private static func createPresenter(
        state: SwapTokensFlowStateProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        selectionModel: SwapAssetSelectionModel,
        selectClosureStrategy: SubmoduleNavigationStrategy,
        selectClosure: @escaping SwapAssetSelectionClosure
    ) -> SwapAssetsOperationPresenter? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = SwapAssetsOperationInteractor(
            state: state,
            selectionModel: selectionModel,
            settingsManager: SettingsManager.shared,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let presenter = SwapAssetsOperationPresenter(
            selectClosure: { chainAsset in
                selectClosure(chainAsset, state)
            },
            selectClosureStrategy: selectClosureStrategy,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            wireframe: SwapAssetsOperationWireframe(
                state: state,
                selectClosure: selectClosure,
                selectClosureStrategy: selectClosureStrategy
            ),
            logger: Logger.shared
        )

        interactor.presenter = presenter

        return presenter
    }
}
