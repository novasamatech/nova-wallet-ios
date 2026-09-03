import Foundation
import Keystore_iOS
import NovaCrypto
import Operation_iOS

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
    let walletNotificationService: WalletNotificationServiceProtocol
    let privacyStateManager: PrivacyStateManagerProtocol
    let operationQueue: OperationQueue
    let pushNotificationsFacade: PushNotificationsServiceFacadeProtocol
    let analyticsConsent: AnalyticsConsentManagerProtocol

    init(
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        walletConnect: WalletConnectDelegateInputProtocol,
        currencyManager: CurrencyManagerProtocol,
        settingsManager: SettingsManagerProtocol,
        biometryAuth: BiometryAuthProtocol,
        walletNotificationService: WalletNotificationServiceProtocol,
        pushNotificationsFacade: PushNotificationsServiceFacadeProtocol,
        analyticsConsent: AnalyticsConsentManagerProtocol,
        privacyStateManager: PrivacyStateManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.walletConnect = walletConnect
        self.walletNotificationService = walletNotificationService
        self.pushNotificationsFacade = pushNotificationsFacade
        self.analyticsConsent = analyticsConsent
        self.privacyStateManager = privacyStateManager
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }
}

// MARK: - Private

private extension SettingsInteractor {
    func provideUserSettings() {
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

    func provideSecuritySettings() {
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

    func provideWalletConnectSessionsCount() {
        let count = walletConnect.getSessionsCount()

        presenter?.didReceiveWalletConnect(sessionsCount: count)
    }

    func providePushNotificationsStatus() {
        pushNotificationsFacade.subscribeStatus(self) { [weak self] _, newStatus in
            self?.presenter?.didReceive(pushNotificationsStatus: newStatus)
        }
    }

    func providePrivacyStateSettings() {
        presenter?.didReceive(hideBalancesOnLaunch: privacyStateManager.enablePrivacyModeOnLaunch)
    }

    /// `nil` when the subsystem is unavailable, so the row disappears rather than showing a
    /// switch that could never take effect.
    func provideAnalyticsSettings() {
        presenter?.didReceive(analyticsEnabled: analyticsConsent.isAvailable ? analyticsConsent.isEnabled : nil)
    }
}

// MARK: - SettingsInteractorInputProtocol

extension SettingsInteractor: SettingsInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        walletConnect.add(delegate: self)

        provideUserSettings()
        provideWalletConnectSessionsCount()
        applyCurrency()
        providePushNotificationsStatus()
        providePrivacyStateSettings()
        provideAnalyticsSettings()

        // The on-launch consent sheet and the opt-out wipe both flip the manager from
        // outside Settings, so the row has to re-provide rather than only echo its own tap.
        analyticsConsent.addObserver(with: self, queue: .main) { [weak self] _, _ in
            self?.provideAnalyticsSettings()
        }

        walletNotificationService.hasUpdatesObservable.addObserver(
            with: self,
            sendStateOnSubscription: true
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveWalletsState(hasUpdates: newState)
        }
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
        walletConnect.connect(uri: uri) { [weak self] error in
            guard let error else { return }

            self?.presenter?.didReceive(error: .walletConnectFailed(error))
        }
    }

    func toggleHideBalances() {
        privacyStateManager.enablePrivacyModeOnLaunch.toggle()
    }

    /// Deliberately does not touch `markPromptSeen()`: the switch is the way back after
    /// declining, and consuming the one-shot prompt state here would change launch behaviour.
    func toggleAnalytics() {
        analyticsConsent.setEnabled(!analyticsConsent.isEnabled)

        provideAnalyticsSettings()
    }
}

// MARK: - EventVisitorProtocol

extension SettingsInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        provideUserSettings()
    }

    func processWalletNameChanged(event: WalletNameChanged) {
        guard event.isSelectedWallet else { return }

        provideUserSettings()
    }
}

// MARK: - WalletConnectDelegateOutputProtocol

extension SettingsInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        provideWalletConnectSessionsCount()
    }
}

// MARK: - SelectedCurrencyDepending

extension SettingsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard
            let presenter,
            let currencyManager
        else { return }

        presenter.didReceive(currencyCode: currencyManager.selectedCurrency.code)
    }
}
