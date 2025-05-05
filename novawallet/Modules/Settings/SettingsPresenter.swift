import Foundation
import Foundation_iOS

final class SettingsPresenter {
    weak var view: SettingsViewProtocol?
    let viewModelFactory: SettingsViewModelFactoryProtocol
    let config: ApplicationConfigProtocol
    let interactor: SettingsInteractorInputProtocol
    let wireframe: SettingsWireframeProtocol
    let logger: LoggerProtocol?
    private var currency: String?
    private var isPinConfirmationOn: Bool = false
    private var biometrySettings: BiometrySettings?
    private var hasWalletsListUpdates: Bool = false
    private var pushNotificationsStatus: PushNotificationsStatus?

    private var wallet: MetaAccountModel?
    private var walletConnectSessionsCount: Int?

    init(
        viewModelFactory: SettingsViewModelFactoryProtocol,
        config: ApplicationConfigProtocol,
        interactor: SettingsInteractorInputProtocol,
        wireframe: SettingsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol?,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
        self.config = config
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let parameters = SettingsParameters(
            walletConnectSessionsCount: walletConnectSessionsCount,
            isBiometricAuthOn: biometrySettings?.isEnabled,
            isPinConfirmationOn: isPinConfirmationOn,
            isNotificationsOn: pushNotificationsStatus == .active
        )

        let sectionViewModels = viewModelFactory.createSectionViewModels(
            language: localizationManager?.selectedLanguage,
            currency: currency,
            parameters: parameters,
            locale: locale
        )

        view?.reload(sections: sectionViewModels)
    }

    private func updateAccountView() {
        guard let wallet = wallet else { return }
        let viewModel = viewModelFactory.createAccountViewModel(
            for: wallet,
            hasWalletNotification: hasWalletsListUpdates
        )
        view?.didLoad(userViewModel: viewModel)
    }

    private func show(url: URL) {
        if let view = view {
            wireframe.show(url: url, from: view)
        }
    }

    private func writeUs() {
        guard let view = view else {
            return
        }

        let message = SocialMessage(
            body: nil,
            subject: nil,
            recepients: [config.supportEmail]
        )

        if !wireframe.writeEmail(with: message, from: view, completionHandler: nil) {
            wireframe.present(
                message: R.string.localizable.noEmailBoundErrorMessage(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                title: R.string.localizable.commonErrorGeneralTitle(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
                from: view
            )
        }
    }

    private func toggleBiometryUsage() {
        guard let biometrySettings = biometrySettings else {
            return
        }

        if biometrySettings.isEnabled == true {
            wireframe.showPincodeAuthorization { [weak self] completed in
                if completed {
                    self?.interactor.updateBiometricAuthSettings(isOn: false)
                }
            }
        } else {
            enableBiometryUsage { [weak self] in
                self?.interactor.updateBiometricAuthSettings(isOn: $0)
            }
        }
    }

    private func enableBiometryUsage(completion: @escaping (Bool) -> Void) {
        guard let biometrySettings = biometrySettings, let view = view else {
            completion(true)
            return
        }

        wireframe.askBiometryUsage(
            from: view,
            biometrySettings: biometrySettings,
            locale: selectedLocale,
            useAction: { completion(true) },
            skipAction: { completion(false) }
        )
    }

    private func toggleConfirmationSettings(
        _ currentState: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        guard let view = view else {
            return
        }
        let newState = !currentState
        let disabling = currentState == true && newState == false
        let enabling = currentState == false && newState == true

        if disabling {
            wireframe.showAuthorization { authorized in
                authorized ? completion(newState) : completion(currentState)
            }
        } else if enabling {
            wireframe.presentConfirmPinHint(
                from: view,
                locale: selectedLocale,
                enableAction: { completion(newState) },
                cancelAction: { completion(currentState) }
            )
        }
    }
}

extension SettingsPresenter: SettingsPresenterProtocol {
    var appNameText: String {
        "\(config.appName) v\(config.version)"
    }

    func setup() {
        updateView()

        interactor.setup()
    }

    // swiftlint:disable:next cyclomatic_complexity
    func actionRow(_ row: SettingsRow) {
        switch row {
        case .wallets:
            wireframe.showAccountSelection(from: view)
        case .currency:
            wireframe.showCurrencies(from: view)
        case .language:
            wireframe.showLanguageSelection(from: view)
        case .appearance:
            wireframe.showAppearance(from: view)
        case .biometricAuth:
            toggleBiometryUsage()
        case .approveWithPin:
            toggleConfirmationSettings(isPinConfirmationOn) { [weak self] newState in
                self?.interactor.updatePinConfirmationSettings(isOn: newState)
            }
        case .changePin:
            wireframe.showPincodeChange(from: view)
        case .telegram:
            show(url: config.socialURL)
        case .youtube:
            show(url: config.youtubeURL)
        case .twitter:
            show(url: config.twitterURL)
        case .rateUs:
            show(url: config.appStoreURL)
        case .email:
            writeUs()
        case .website:
            show(url: config.websiteURL)
        case .github:
            show(url: config.opensourceURL)
        case .terms:
            show(url: config.termsURL)
        case .privacyPolicy:
            show(url: config.privacyPolicyURL)
        case .walletConnect:
            if let count = walletConnectSessionsCount, count > 0 {
                wireframe.showWalletConnect(from: view)
            } else {
                wireframe.showScan(from: view, delegate: self)
            }
        case .wiki:
            show(url: config.wikiURL)
        case .notifications:
            guard pushNotificationsStatus != nil else {
                return
            }

            wireframe.showManageNotifications(from: view)
        case .backup:
            wireframe.showBackup(from: view)
        case .networks:
            wireframe.showNetworks(from: view)
        }
    }

    func handleWalletAction() {
        guard let wallet = wallet else { return }
        wireframe.showAccountDetails(for: wallet.identifier, from: view)
    }

    func handleSwitchAction() {
        wireframe.showWalletSwitch(from: view)
    }
}

extension SettingsPresenter: SettingsInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet
        updateAccountView()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive user data provider \(error)")

        let locale = localizationManager?.selectedLocale ?? Locale.current

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
        }
    }

    func didReceive(currencyCode: String) {
        currency = currencyCode

        if view?.isSetup == true {
            updateView()
        }
    }

    func didReceive(biometrySettings: BiometrySettings) {
        self.biometrySettings = biometrySettings
        if view?.isSetup == true {
            updateView()
        }
    }

    func didReceive(pinConfirmationEnabled: Bool) {
        isPinConfirmationOn = pinConfirmationEnabled

        if view?.isSetup == true {
            updateView()
        }
    }

    func didReceive(error: SettingsError) {
        logger?.error("Did receive wc error: \(error)")

        switch error {
        case .biometryAuthAndSystemSettingsOutOfSync:
            guard let biometrySettings = biometrySettings else {
                return
            }

            let biometryTypeName = biometrySettings.name
            let title = R.string.localizable.settingsErrorBiometryDisabledInSettingsTitle(
                biometryTypeName,
                preferredLanguages: selectedLocale.rLanguages
            )
            let message = R.string.localizable.settingsErrorBiometryDisabledInSettingsMessage(
                biometryTypeName,
                preferredLanguages: selectedLocale.rLanguages
            )

            wireframe.askOpenApplicationSettings(
                with: message,
                title: title,
                from: view,
                locale: selectedLocale
            )
        case let .walletConnectFailed(internalError):
            wireframe.presentWCConnectionError(from: view, error: internalError, locale: selectedLocale)
        }
    }

    func didReceiveWalletConnect(sessionsCount: Int) {
        walletConnectSessionsCount = sessionsCount

        updateView()
    }

    func didReceiveWalletsState(hasUpdates: Bool) {
        hasWalletsListUpdates = hasUpdates
        updateAccountView()
    }

    func didReceive(pushNotificationsStatus: PushNotificationsStatus) {
        self.pushNotificationsStatus = pushNotificationsStatus
        updateView()
    }
}

extension SettingsPresenter: URIScanDelegate {
    func uriScanDidReceive(uri: String, context _: AnyObject?) {
        wireframe.hideUriScanAnimated(from: view) { [weak self] in
            self?.interactor.connectWalletConnect(uri: uri)
        }
    }
}

extension SettingsPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
