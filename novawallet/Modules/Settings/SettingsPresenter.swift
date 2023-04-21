import Foundation
import SoraFoundation

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

    private var wallet: MetaAccountModel?

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

        let sectionViewModels = viewModelFactory.createSectionViewModels(
            language: localizationManager?.selectedLanguage,
            currency: currency,
            isBiometricAuthOn: biometrySettings?.isEnabled,
            isPinConfirmationOn: isPinConfirmationOn,
            locale: locale
        )
        view?.reload(sections: sectionViewModels)
    }

    private func updateAccountView() {
        guard let wallet = wallet else { return }
        let viewModel = viewModelFactory.createAccountViewModel(for: wallet)
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
            interactor.updateBiometricAuthSettings(isOn: false)
        } else {
            enableBiometryUsage { [weak self] in
                self?.interactor.updateBiometricAuthSettings(isOn: $0)
            }
        }
    }

    private func enableBiometryUsage(completion: @escaping (Bool) -> Void) {
        guard let alertModel = viewModelFactory.askBiometryAlert(biometrySettings: biometrySettings,
                                                                 locale: selectedLocale,
                                                                 useAction: { completion(true) },
                                                                 skipAction: { completion(false) }) else {
            completion(true)
            return
        }
        
        wireframe.present(viewModel: alertModel, style: .alert, from: view)
    }

    private func toggleConfirmationSettings(
        _ currentState: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        let newState = currentState.toggled()
        let disabling = currentState == true && newState == false
        let enabling = currentState == false && newState == true
        
        if disabling {
            wireframe.showPincode { authorized in
                authorized ? completion(newState) : completion(currentState)
            }
        } else if enabling {
            let alertModel = viewModelFactory.createConfirmPinInfoAlert(locale: selectedLocale,
                                                                        enableAction: { completion(newState) },
                                                                        cancelAction: { completion(currentState) })
            wireframe.present(
                viewModel: alertModel,
                style: .alert,
                from: view
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

    func didReceiveSettings(biometrySettings: BiometrySettings, isPinConfirmationOn: Bool) {
        self.biometrySettings = biometrySettings
        self.isPinConfirmationOn = isPinConfirmationOn

        if view?.isSetup == true {
            updateView()
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

extension Bool {
    func toggled() -> Bool {
        var updatingValue = self
        updatingValue.toggle()
        return updatingValue
    }
}
