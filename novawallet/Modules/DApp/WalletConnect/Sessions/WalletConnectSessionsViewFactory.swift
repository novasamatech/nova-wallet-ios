import Foundation
import Foundation_iOS

struct WalletConnectSessionsViewFactory {
    static func createView(
        with dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionsViewProtocol? {
        guard let interactor = createInteractor(with: dappMediator) else {
            return nil
        }

        let wireframe = WalletConnectSessionsWireframe(dappMediator: dappMediator)

        let localizationManager = LocalizationManager.shared

        let presenter = WalletConnectSessionsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: WalletConnectSessionsViewModelFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletConnectSessionsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createViewForCurrentWallet(
        with dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionsViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value,
              let interactor = createSingleWalletInteractor(with: dappMediator, wallet: wallet) else {
            return nil
        }

        let wireframe = WalletConnectSessionsWireframe(dappMediator: dappMediator)

        let localizationManager = LocalizationManager.shared

        let presenter = WalletConnectSessionsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: WalletConnectSessionsViewModelFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletConnectSessionsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        with dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionsInteractor? {
        guard
            let walletConnect = dappMediator.children.first(
                where: { $0 is WalletConnectDelegateInputProtocol }
            ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        return .init(walletConnect: walletConnect)
    }

    private static func createSingleWalletInteractor(
        with dappMediator: DAppInteractionMediating,
        wallet: MetaAccountModel
    ) -> WalletConnectSessionsInteractor? {
        guard
            let walletConnect = dappMediator.children.first(
                where: { $0 is WalletConnectDelegateInputProtocol }
            ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        return .init(walletConnect: walletConnect, sessionFilter: { $0.wallet?.identifier == wallet.identifier })
    }
}
