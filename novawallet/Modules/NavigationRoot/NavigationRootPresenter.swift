import Foundation
import Foundation_iOS

final class NavigationRootPresenter {
    weak var view: NavigationRootViewProtocol?
    let wireframe: NavigationRootWireframeProtocol
    let interactor: NavigationRootInteractorInputProtocol

    let walletSwitchViewModelFactory: WalletSwitchViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var wallet: MetaAccountModel?
    private var hasNotification: Bool = false
    private var walletConnectSessions: Int = 0

    init(
        interactor: NavigationRootInteractorInputProtocol,
        wireframe: NavigationRootWireframeProtocol,
        walletSwitchViewModelFactory: WalletSwitchViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.walletSwitchViewModelFactory = walletSwitchViewModelFactory
        self.localizationManager = localizationManager
    }
}

private extension NavigationRootPresenter {
    func provideWalletSwitchViewModel() {
        guard let wallet else {
            return
        }

        let viewModel = walletSwitchViewModelFactory.createViewModel(
            from: wallet,
            hasNotification: hasNotification
        )

        view?.didReceive(walletSwitchViewModel: viewModel)
    }
}

extension NavigationRootPresenter: NavigationRootPresenterProtocol {
    func setup() {
        view?.didReceive(walletConnectSessions: walletConnectSessions)

        interactor.setup()
    }

    func activateSettings() {
        wireframe.showSettings(from: view)
    }

    func activateCloudBackupSettings() {
        wireframe.showCloudBackupSettins(from: view)
    }

    func activateWalletSelection() {
        wireframe.showWalletSwitch(from: view)
    }

    func activateWalletConnect() {
        if walletConnectSessions > 0 {
            wireframe.showWalletConnect(from: view)
        } else {
            wireframe.showScan(from: view, delegate: self)
        }
    }
}

extension NavigationRootPresenter: NavigationRootInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet

        provideWalletSwitchViewModel()
    }

    func didReceiveWalletConnect(sessionsCount: Int) {
        guard walletConnectSessions != sessionsCount else {
            return
        }

        walletConnectSessions = sessionsCount

        view?.didReceive(walletConnectSessions: sessionsCount)
    }

    func didReceiveWalletConnect(error: WalletConnectSessionsError) {
        switch error {
        case let .connectionFailed(internalError):
            wireframe.presentWCConnectionError(
                from: view,
                error: internalError,
                locale: localizationManager.selectedLocale
            )
        case .sessionsFetchFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.interactor.retryFetchWalletConnectSessionsCount()
            }
        }
    }

    func didReceiveWalletsState(hasUpdates: Bool) {
        guard hasNotification != hasUpdates else {
            return
        }

        hasNotification = hasUpdates

        provideWalletSwitchViewModel()
    }
}

extension NavigationRootPresenter: URIScanDelegate {
    func uriScanDidReceive(uri: String, context _: AnyObject?) {
        wireframe.hideUriScanAnimated(from: view) { [weak self] in
            self?.interactor.connectWalletConnect(uri: uri)
        }
    }
}
