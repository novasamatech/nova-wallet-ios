import Foundation
import SoraFoundation

enum SwapAssetsOperationViewFactory {
    static func createSelectPayTokenView(
        for stateObservable: AssetListModelObservable,
        chainAsset: ChainAsset? = nil,
        selectClosureStrategy: SubmoduleNavigationStrategy = .callbackBeforeDismissal,
        selectClosure: @escaping (ChainAsset) -> Void
    ) -> AssetsSearchViewProtocol? {
        let title: LocalizableResource<String> = .init {
            R.string.localizable.swapsPayTokenSelectionTitle(
                preferredLanguages: $0.rLanguages
            )
        }

        return createView(
            for: stateObservable,
            chainAsset: chainAsset,
            title: title,
            selectClosureStrategy: selectClosureStrategy,
            selectClosure: selectClosure
        )
    }

    static func createSelectReceiveTokenView(
        for stateObservable: AssetListModelObservable,
        chainAsset: ChainAsset? = nil,
        selectClosureStrategy: SubmoduleNavigationStrategy = .callbackBeforeDismissal,
        selectClosure: @escaping (ChainAsset) -> Void
    ) -> AssetsSearchViewProtocol? {
        let title: LocalizableResource<String> = .init {
            R.string.localizable.swapsReceiveTokenSelectionTitle(
                preferredLanguages: $0.rLanguages
            )
        }

        return createView(
            for: stateObservable,
            chainAsset: chainAsset,
            title: title,
            selectClosureStrategy: selectClosureStrategy,
            selectClosure: selectClosure
        )
    }

    static func createView(
        for stateObservable: AssetListModelObservable,
        chainAsset: ChainAsset? = nil,
        title: LocalizableResource<String>,
        selectClosureStrategy: SubmoduleNavigationStrategy,
        selectClosure: @escaping (ChainAsset) -> Void
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
            currencyManager: currencyManager
        )

        guard let presenter = createPresenter(
            stateObservable: stateObservable,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
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
        stateObservable: AssetListModelObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        chainAsset: ChainAsset?,
        selectClosureStrategy: SubmoduleNavigationStrategy,
        selectClosure: @escaping (ChainAsset) -> Void
    ) -> SwapAssetsOperationPresenter? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionAggregator = AssetConversionAggregationFactory(
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let interactor = SwapAssetsOperationInteractor(
            stateObservable: stateObservable,
            chainAsset: chainAsset,
            assetConversionAggregation: assetConversionAggregator,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let presenter = SwapAssetsOperationPresenter(
            selectClosure: selectClosure,
            selectClosureStrategy: selectClosureStrategy,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            wireframe: SwapAssetsOperationWireframe(),
            logger: Logger.shared
        )

        interactor.presenter = presenter

        return presenter
    }
}
