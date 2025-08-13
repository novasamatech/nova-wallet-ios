import Foundation
import Foundation_iOS

final class MultisigOperationsViewFactory {
    static func createView() -> MultisigOperationsViewProtocol? {
        guard
            let selectedWallet = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let wireframe = MultisigOperationsWireframe()

        let walletsRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let pendingOperationsProvider = MultisigOperationProviderProxy(
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
            callFormattingFactory: CallFormattingOperationFactory(
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                walletRepository: walletsRepository
            ),
            operationQueue: operationQueue
        )

        let interactor = MultisigOperationsInteractor(
            wallet: selectedWallet,
            pendingOperationsProvider: pendingOperationsProvider,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: operationQueue
        )

        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
        let viewModelFactory = MultisigOperationsViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let localizationManager = LocalizationManager.shared

        let presenter = MultisigOperationsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            wallet: selectedWallet,
            localizationManager: localizationManager
        )

        let controller = MultisigOperationsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = controller
        interactor.presenter = presenter

        return controller
    }
}
