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

// MARK: BUY/SELL

extension AssetOperationNetworkListViewFactory {
    static func createBuyView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol
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

        let baseRampPresenterDependencies = RampPresenterDependencies.Base(
            interactor: interactor,
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            rampProvider: rampProvider,
            currencyManager: currencyManager
        )
        let presenter = createRampPresenter(
            dependencies: createOnRampPresenterDependencies(base: baseRampPresenterDependencies)
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createSellView(
        with multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol
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

        let baseRampPresenterDependencies = RampPresenterDependencies.Base(
            interactor: interactor,
            multichainToken: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            rampProvider: rampProvider,
            currencyManager: currencyManager
        )
        let presenter = createRampPresenter(
            dependencies: createOffRampPresenterDependencies(base: baseRampPresenterDependencies)
        )

        let view = AssetOperationNetworkListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createOnRampPresenterDependencies(
        base: RampPresenterDependencies.Base
    ) -> RampPresenterDependencies {
        .init(
            base: base,
            closures: .init(
                checkResultClosure: TokenOperation.checkBuyOperationAvailable,
                rampActionsProviderClosure: { $0.buildOnRampActions },
                flowManagingClosure: { $0.startOnRampFlow },
                rampCompletionClosure: { $0.presentOnRampDidComplete }
            )
        )
    }

    private static func createOffRampPresenterDependencies(
        base: RampPresenterDependencies.Base
    ) -> RampPresenterDependencies {
        .init(
            base: base,
            closures: .init(
                checkResultClosure: TokenOperation.checkSellOperationAvailable,
                rampActionsProviderClosure: { $0.buildOffRampActions },
                flowManagingClosure: { $0.startOffRampFlow },
                rampCompletionClosure: { $0.presentOffRampDidComplete }
            )
        )
    }

    private static func createRampPresenter(
        dependencies: RampPresenterDependencies
    ) -> RampOperationNetworkListPresenter {
        let viewModelFactory = createViewModelFactory(with: dependencies.base.currencyManager)

        let wireframe = BuyAssetOperationWireframe(stateObservable: dependencies.base.stateObservable)

        return RampOperationNetworkListPresenter(
            interactor: dependencies.base.interactor,
            wireframe: wireframe,
            rampProvider: dependencies.base.rampProvider,
            multichainToken: dependencies.base.multichainToken,
            viewModelFactory: viewModelFactory,
            selectedAccount: dependencies.base.selectedAccount,
            checkResultClosure: dependencies.closures.checkResultClosure,
            rampActionsProviderClosure: dependencies.closures.rampActionsProviderClosure,
            flowManagingClosure: dependencies.closures.flowManagingClosure,
            rampCompletionClosure: dependencies.closures.rampCompletionClosure,
            localizationManager: LocalizationManager.shared
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
            selectedAccount: dependencies.selectedAccount,
            localizationManager: LocalizationManager.shared
        )
    }
}

// MARK: SWAPS

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

private extension AssetOperationNetworkListViewFactory {
    struct SendPresenterDependencies {
        let interactor: AssetOperationNetworkListInteractor
        let multichainToken: MultichainToken
        let stateObservable: AssetListModelObservable
        let transferCompletion: TransferCompletionClosure?
        let currencyManager: CurrencyManager
    }

    struct RampPresenterDependencies {
        struct Closures {
            let checkResultClosure: RampOperationAvailabilityCheckClosure
            let rampActionsProviderClosure: RampActionProviderClosure
            let flowManagingClosure: RampFlowManagingClosure
            let rampCompletionClosure: RampCompletionClosure
        }

        struct Base {
            let interactor: AssetOperationNetworkListInteractor
            let multichainToken: MultichainToken
            let stateObservable: AssetListModelObservable
            let selectedAccount: MetaAccountModel
            let rampProvider: RampProviderProtocol
            let currencyManager: CurrencyManager
        }

        let base: Base
        let closures: Closures
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
}
