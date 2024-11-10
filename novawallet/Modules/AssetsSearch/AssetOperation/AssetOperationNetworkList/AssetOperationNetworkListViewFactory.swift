import Foundation
import SoraFoundation

struct AssetOperationNetworkListViewFactory {
    static func createSendView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        transferCompletion: TransferCompletionClosure?
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let logger = Logger.shared

        let interactor = SendAssetOperationNetworkListInteractor(
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
            viewModelFactory: viewModelFactory
        )
    }

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

// MARK: BUY

extension AssetOperationNetworkListViewFactory {
    static func createBuyView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectedAccount: MetaAccountModel,
        purchaseProvider: PurchaseProviderProtocol
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

        let presenter = createBuyPresenter(
            dependencies: BuyPresenterDependencies(
                interactor: interactor,
                multichainToken: multichainToken,
                stateObservable: stateObservable,
                selectedAccount: selectedAccount,
                purchaseProvider: purchaseProvider,
                currencyManager: currencyManager
            )
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createBuyPresenter(
        dependencies: BuyPresenterDependencies
    ) -> BuyOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.currencyManager)

        let wireframe = BuyAssetOperationWireframe(stateObservable: dependencies.stateObservable)

        return BuyOperationNetworkListPresenter(
            interactor: dependencies.interactor,
            wireframe: wireframe,
            multichainToken: dependencies.multichainToken,
            viewModelFactory: viewModelFactory,
            selectedAccount: dependencies.selectedAccount,
            purchaseProvider: dependencies.purchaseProvider
        )
    }
}

// MARK: RECEIVE

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
            selectedAccount: dependencies.selectedAccount
        )
    }
}

// MARK: SWAPS

extension AssetOperationNetworkListViewFactory {
    static func createSwapsView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectClosure: @escaping (ChainAsset) -> Void,
        selectClosureStrategy: SubmoduleNavigationStrategy
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let logger = Logger.shared

        let interactor = SendAssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            logger: logger
        )

        let presenter = createSwapPresenter(
            dependencies: SwapPresenterDependencies(
                interactor: interactor,
                multichainToken: multichainToken,
                stateObservable: stateObservable,
                currencyManager: currencyManager,
                selectClosure: selectClosure,
                selectClosureStrategy: selectClosureStrategy
            )
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createSwapPresenter(
        dependencies: SwapPresenterDependencies
    ) -> SwapOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.currencyManager)

        let wireframe = SwapAssetsOperationWireframe(stateObservable: dependencies.stateObservable)

        return SwapOperationNetworkListPresenter(
            interactor: dependencies.interactor,
            wireframe: wireframe,
            multichainToken: dependencies.multichainToken,
            viewModelFactory: viewModelFactory,
            selectClosure: dependencies.selectClosure,
            selectClosureStrategy: dependencies.selectClosureStrategy
        )
    }
}

private extension AssetOperationNetworkListViewFactory {
    struct SendPresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let stateObservable: AssetListModelObservable
        let transferCompletion: TransferCompletionClosure?
        let currencyManager: CurrencyManager
    }

    struct BuyPresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let stateObservable: AssetListModelObservable
        let selectedAccount: MetaAccountModel
        let purchaseProvider: PurchaseProviderProtocol
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
        let stateObservable: AssetListModelObservable
        let currencyManager: CurrencyManager
        let selectClosure: (ChainAsset) -> Void
        let selectClosureStrategy: SubmoduleNavigationStrategy
    }
}
