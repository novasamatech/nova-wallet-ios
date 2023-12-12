import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood

enum ProfileInteractorError: Error {
    case noSelectedAccount
}

final class SettingsInteractor {
    weak var presenter: SettingsInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings
    let settingsManager: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let biometryAuth: BiometryAuthProtocol
    let walletConnect: WalletConnectDelegateInputProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol
    private var walletListSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        walletConnect: WalletConnectDelegateInputProtocol,
        currencyManager: CurrencyManagerProtocol,
        settingsManager: SettingsManagerProtocol,
        biometryAuth: BiometryAuthProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.walletConnect = walletConnect
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.logger = logger
        self.currencyManager = currencyManager
    }

    private func provideUserSettings() {
        do {
            guard let wallet = selectedWalletSettings.value else {
                throw ProfileInteractorError.noSelectedAccount
            }
            presenter?.didReceive(wallet: wallet)
        } catch {
            presenter?.didReceiveUserDataProvider(error: error)
        }

        provideSecuritySettings()
    }

    private func provideSecuritySettings() {
        let biometrySettings: BiometrySettings = .create(
            from: biometryAuth.supportedBiometryType,
            settingsManager: settingsManager
        )
        let pinConfirmationEnabled = settingsManager.pinConfirmationEnabled ?? false

        DispatchQueue.main.async {
            self.presenter?.didReceive(biometrySettings: biometrySettings)
            self.presenter?.didReceive(pinConfirmationEnabled: pinConfirmationEnabled)
        }
    }

    private func provideWalletConnectSessionsCount() {
        let count = walletConnect.getSessionsCount()

        presenter?.didReceiveWalletConnect(sessionsCount: count)
    }
}

extension SettingsInteractor: SettingsInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        walletConnect.add(delegate: self)

        provideUserSettings()
        provideWalletConnectSessionsCount()
        applyCurrency()
        walletListSubscription = subscribeNewProxyWallets()
    }

    func updateBiometricAuthSettings(isOn: Bool) {
        if isOn,
           biometryAuth.availableBiometryType == .none,
           biometryAuth.supportedBiometryType != .none {
            presenter?.didReceive(error: .biometryAuthAndSystemSettingsOutOfSync)
        }

        settingsManager.biometryEnabled = isOn
        provideSecuritySettings()
    }

    func updatePinConfirmationSettings(isOn: Bool) {
        settingsManager.pinConfirmationEnabled = isOn
        provideSecuritySettings()
    }

    func connectWalletConnect(uri: String) {
        walletConnect.connect(uri: uri) { [weak self] optError in
            if let error = optError {
                self?.presenter?.didReceive(error: .walletConnectFailed(error))
            }
        }
    }
}

extension SettingsInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideUserSettings()
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        provideUserSettings()
    }
}

extension SettingsInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        provideWalletConnectSessionsCount()
    }
}

extension SettingsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard let presenter = presenter,
              let currencyManager = self.currencyManager else {
            return
        }

        presenter.didReceive(currencyCode: currencyManager.selectedCurrency.code)
    }
}

extension SettingsInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleNewProxyWalletsUpdate(result: Result<Int, Error>) {
        switch result {
        case let .success(count):
            presenter?.didReceiveWalletsState(hasUpdates: count > 0)
        case let .failure(error):
            logger.error("Unexpected new proxy wallets update error: \(error)")
        }
    }
}
