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

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            logger: logger
        )

        let presenter = createSendPresenter(
            with: interactor,
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            transferCompletion: transferCompletion,
            currencyManager: currencyManager
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createSendPresenter(
        with interactor: AssetOperationNetworkListInteractor,
        multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        transferCompletion: TransferCompletionClosure?,
        currencyManager: CurrencyManager
    ) -> SendOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: currencyManager)

        let wireframe = SendAssetOperationWireframe(
            stateObservable: stateObservable,
            buyTokensClosure: nil,
            transferCompletion: transferCompletion
        )

        return SendOperationNetworkListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
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
            with: interactor,
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            purchaseProvider: purchaseProvider,
            currencyManager: currencyManager
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createBuyPresenter(
        with interactor: AssetOperationNetworkListInteractor,
        multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectedAccount: MetaAccountModel,
        purchaseProvider: PurchaseProviderProtocol,
        currencyManager: CurrencyManager
    ) -> BuyOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: currencyManager)

        let wireframe = BuyAssetOperationWireframe(stateObservable: stateObservable)

        return BuyOperationNetworkListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            selectedAccount: selectedAccount,
            purchaseProvider: purchaseProvider
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
            with: interactor,
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            currencyManager: currencyManager
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createReceivePresenter(
        with interactor: AssetOperationNetworkListInteractor,
        multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectedAccount: MetaAccountModel,
        currencyManager: CurrencyManager
    ) -> ReceiveOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: currencyManager)

        let wireframe = ReceiveAssetOperationWireframe(stateObservable: stateObservable)

        return ReceiveOperationNetworkListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            selectedAccount: selectedAccount
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

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            logger: logger
        )

        let presenter = createSwapPresenter(
            with: interactor,
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            currencyManager: currencyManager,
            selectClosure: selectClosure,
            selectClosureStrategy: selectClosureStrategy
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createSwapPresenter(
        with interactor: AssetOperationNetworkListInteractor,
        multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        currencyManager: CurrencyManager,
        selectClosure: @escaping (ChainAsset) -> Void,
        selectClosureStrategy: SubmoduleNavigationStrategy
    ) -> SwapOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: currencyManager)

        let wireframe = SwapAssetsOperationWireframe(stateObservable: stateObservable)

        return SwapOperationNetworkListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            selectClosure: selectClosure,
            selectClosureStrategy: selectClosureStrategy
        )
    }
}
