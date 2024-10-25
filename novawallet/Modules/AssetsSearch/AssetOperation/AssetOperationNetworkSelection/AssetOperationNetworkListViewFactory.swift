import Foundation
import SoraFoundation

struct AssetOperationNetworkListViewFactory {
    static func createSendView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operation = OperationQueue()
        operation.maxConcurrentOperationCount = 1

        let logger = Logger.shared

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            operationQueue: operation,
            stateObservable: stateObservable,
            logger: logger
        )
        let wireframe = AssetOperationNetworkListWireframe()

        let presenter = createSendPresenter(
            with: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            currencyManager: currencyManager
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createSendPresenter(
        with interactor: AssetOperationNetworkListInteractor,
        wireframe: AssetOperationNetworkListWireframe,
        multichainToken: MultichainToken,
        currencyManager: CurrencyManager
    ) -> SendOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: currencyManager)

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
        stateObservable: AssetListModelObservable
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operation = OperationQueue()
        operation.maxConcurrentOperationCount = 1

        let logger = Logger.shared

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            operationQueue: operation,
            stateObservable: stateObservable,
            logger: logger
        )
        let wireframe = AssetOperationNetworkListWireframe()

        let presenter = createBuyPresenter(
            with: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            currencyManager: currencyManager
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createBuyPresenter(
        with interactor: AssetOperationNetworkListInteractor,
        wireframe: AssetOperationNetworkListWireframe,
        multichainToken: MultichainToken,
        currencyManager: CurrencyManager
    ) -> BuyOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: currencyManager)

        return BuyOperationNetworkListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory
        )
    }
}

// MARK: RECEIVE

extension AssetOperationNetworkListViewFactory {
    static func createReceiveView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable
    ) -> AssetOperationNetworkListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operation = OperationQueue()
        operation.maxConcurrentOperationCount = 1

        let logger = Logger.shared

        let interactor = AssetOperationNetworkListInteractor(
            multichainToken: multichainToken,
            operationQueue: operation,
            stateObservable: stateObservable,
            logger: logger
        )
        let wireframe = AssetOperationNetworkListWireframe()

        let presenter = createReceivePresenter(
            with: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            currencyManager: currencyManager
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createReceivePresenter(
        with interactor: AssetOperationNetworkListInteractor,
        wireframe: AssetOperationNetworkListWireframe,
        multichainToken: MultichainToken,
        currencyManager: CurrencyManager
    ) -> ReceiveOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: currencyManager)

        return ReceiveOperationNetworkListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory
        )
    }
}
