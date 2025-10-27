import Foundation
import Foundation_iOS

struct AssetOperationNetworkListViewFactory {
    private static func createViewModelFactory(
        with currencyManager: CurrencyManager
    ) -> AssetOperationNetworkListViewModelFactory {
        let networkViewModelFactory = NetworkViewModelFactory()
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(
            networkViewModelFactory: networkViewModelFactory
        )
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let assetFormatterFactory = AssetBalanceFormatterFactory()

        let viewModelFactory = AssetOperationNetworkListViewModelFactory(
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: assetFormatterFactory
        )

        return viewModelFactory
    }
}

// MARK: - SEND

extension AssetOperationNetworkListViewFactory {
    static func createSendView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        transferCompletion: TransferCompletionClosure?
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let logger = Logger.shared

        let interactor = SpendAssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            logger: logger
        )

        let presenter = createSendPresenter(
            dependencies: SendPresenterDependencies(
                interactor: interactor,
                multichainToken: multichainToken,
                stateObservable: stateObservable,
                transferCompletion: transferCompletion,
                currencyManager: currencyManager
            )
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createSendPresenter(
        dependencies: SendPresenterDependencies
    ) -> SendOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.currencyManager)

        let wireframe = SendAssetOperationWireframe(
            stateObservable: dependencies.stateObservable,
            buyTokensClosure: nil,
            transferCompletion: dependencies.transferCompletion
        )

        return SendOperationNetworkListPresenter(
            interactor: dependencies.interactor,
            wireframe: wireframe,
            multichainToken: dependencies.multichainToken,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )
    }
}

// MARK: - RAMP

extension AssetOperationNetworkListViewFactory {
    static func createRampView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol,
        rampType: RampActionType,
        delegate: RampFlowStartingDelegate?
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let logger = Logger.shared

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            logger: logger
        )

        let presenterDependencies = RampPresenterDependencies(
            interactor: interactor,
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            rampProvider: rampProvider,
            rampType: rampType,
            currencyManager: currencyManager
        )
        let presenter = createRampPresenter(
            dependencies: presenterDependencies,
            flowStartingDelegate: delegate
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createRampPresenter(
        dependencies: RampPresenterDependencies,
        flowStartingDelegate: RampFlowStartingDelegate?
    ) -> RampOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.currencyManager)

        let wireframe = RampAssetOperationWireframe(
            delegate: flowStartingDelegate,
            stateObservable: dependencies.stateObservable
        )

        let presenter = RampOperationNetworkListPresenter(
            interactor: dependencies.interactor,
            wireframe: wireframe,
            rampProvider: dependencies.rampProvider,
            rampType: dependencies.rampType,
            multichainToken: dependencies.multichainToken,
            viewModelFactory: viewModelFactory,
            selectedAccount: dependencies.selectedAccount,
            localizationManager: LocalizationManager.shared
        )

        presenter.delegate = flowStartingDelegate

        return presenter
    }
}

// MARK: - RECEIVE

extension AssetOperationNetworkListViewFactory {
    static func createReceiveView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectedAccount: MetaAccountModel
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let logger = Logger.shared

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            logger: logger
        )

        let presenter = createReceivePresenter(
            dependencies: ReceivePresenterDependencies(
                interactor: interactor,
                multichainToken: multichainToken,
                stateObservable: stateObservable,
                selectedAccount: selectedAccount,
                currencyManager: currencyManager
            )
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createReceivePresenter(
        dependencies: ReceivePresenterDependencies
    ) -> ReceiveOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.currencyManager)

        let wireframe = ReceiveAssetOperationWireframe(stateObservable: dependencies.stateObservable)

        return ReceiveOperationNetworkListPresenter(
            interactor: dependencies.interactor,
            wireframe: wireframe,
            multichainToken: dependencies.multichainToken,
            viewModelFactory: viewModelFactory,
            selectedAccount: dependencies.selectedAccount,
            localizationManager: LocalizationManager.shared
        )
    }
}

// MARK: - SWAPS

extension AssetOperationNetworkListViewFactory {
    static func createSwapsView(
        with multichainToken: MultichainToken,
        state: SwapTokensFlowStateProtocol,
        selectClosure: @escaping SwapAssetSelectionClosure,
        selectClosureStrategy: SubmoduleNavigationStrategy
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let logger = Logger.shared

        let interactor = SpendAssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: state.assetListObservable,
            logger: logger
        )

        let presenter = createSwapPresenter(
            dependencies: SwapPresenterDependencies(
                interactor: interactor,
                multichainToken: multichainToken,
                state: state,
                currencyManager: currencyManager,
                selectClosure: selectClosure,
                selectClosureStrategy: selectClosureStrategy
            )
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view

        return view
    }

    private static func createSwapPresenter(
        dependencies: SwapPresenterDependencies
    ) -> SwapOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.currencyManager)

        let wireframe = SwapAssetsOperationWireframe(
            state: dependencies.state,
            selectClosure: dependencies.selectClosure,
            selectClosureStrategy: dependencies.selectClosureStrategy
        )

        let presenter = SwapOperationNetworkListPresenter(
            interactor: dependencies.interactor,
            wireframe: wireframe,
            multichainToken: dependencies.multichainToken,
            viewModelFactory: viewModelFactory,
            selectClosure: { chainAsset in
                dependencies.selectClosure(chainAsset, dependencies.state)
            },
            selectClosureStrategy: dependencies.selectClosureStrategy,
            localizationManager: LocalizationManager.shared
        )

        dependencies.interactor.presenter = presenter

        return presenter
    }
}

// MARK: - GIFTS

extension AssetOperationNetworkListViewFactory {
    static func createGiftsView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let logger = Logger.shared

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            logger: logger
        )

        let presenter = createGiftsPresenter(
            dependencies: GiftPresenterDependencies(
                interactor: interactor,
                multichainToken: multichainToken,
                stateObservable: stateObservable,
                currencyManager: currencyManager,
                transferCompletion: transferCompletion,
                buyTokensClosure: buyTokensClosure
            )
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createGiftsPresenter(
        dependencies: GiftPresenterDependencies
    ) -> GiftOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.currencyManager)

        let wireframe = GiftAssetOperationWireframe(
            stateObservable: dependencies.stateObservable,
            buyTokensClosure: dependencies.buyTokensClosure,
            transferCompletion: dependencies.transferCompletion
        )

        return GiftOperationNetworkListPresenter(
            interactor: dependencies.interactor,
            wireframe: wireframe,
            multichainToken: dependencies.multichainToken,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )
    }
}

// MARK: - Private types

private extension AssetOperationNetworkListViewFactory {
    struct SendPresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let stateObservable: AssetListModelObservable
        let transferCompletion: TransferCompletionClosure?
        let currencyManager: CurrencyManager
    }

    struct RampPresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let stateObservable: AssetListModelObservable
        let selectedAccount: MetaAccountModel
        let rampProvider: RampProviderProtocol
        let rampType: RampActionType
        let currencyManager: CurrencyManager
    }

    struct ReceivePresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let stateObservable: AssetListModelObservable
        let selectedAccount: MetaAccountModel
        let currencyManager: CurrencyManager
    }

    struct SwapPresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let state: SwapTokensFlowStateProtocol
        let currencyManager: CurrencyManager
        let selectClosure: SwapAssetSelectionClosure
        let selectClosureStrategy: SubmoduleNavigationStrategy
    }

    struct GiftPresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let stateObservable: AssetListModelObservable
        let currencyManager: CurrencyManager
        let transferCompletion: TransferCompletionClosure
        let buyTokensClosure: BuyTokensClosure
    }
}
