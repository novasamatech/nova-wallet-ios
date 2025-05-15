import Foundation
import Foundation_iOS
import Keystore_iOS

struct PayShopViewFactory {
    static func createView() -> PayShopViewProtocol? {
        guard
            let chain = ChainRegistryFacade.sharedRegistry.getChain(for: RaiseModel.chainId),
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetch(for: chain.accountRequest()) else {
            // TODO: Validate selected account and create unavailable state here
            return nil
        }

        let interactor = createInteractor(for: selectedAccount)
        let wireframe = PayShopWireframe()

        let presenter = PayShopPresenter(
            interactor: interactor,
            wireframe: wireframe,
            brandModelFactory: PayShopBrandViewModelFactory(),
            listViewModelFactory: PayShopViewModelFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = PayShopViewController(presenter: presenter)

        presenter.baseView = view
        interactor.presenter = presenter

        return view
    }
}

private extension PayShopViewFactory {
    static func createInteractor(for selectedAccount: ChainAccountResponse) -> PayShopInteractor {
        let customerProvider = RaiseWalletCustomerProvider(account: selectedAccount)

        let keychain = Keychain()
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let authStore = RaiseAuthKeyStorage(keystore: keychain, account: selectedAccount)

        let operationFactory = RaiseOperationFactory(
            authProvider: RaiseAuthProvider(
                authFactory: RaiseAuthFactory(
                    keystore: authStore,
                    customerProvider: customerProvider,
                    operationQueue: operationQueue
                ),
                authStore: authStore,
                operationQueue: operationQueue,
                logger: Logger.shared
            ),
            customerProvider: customerProvider,
            operationQueue: operationQueue
        )

        return PayShopInteractor(
            operationFactory: operationFactory,
            raiseProviderFactory: RaiseProviderFactory(operationFactory: operationFactory),
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
