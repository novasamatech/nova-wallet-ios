import Foundation
import SoraFoundation

final class SettingsPresenter {
    weak var view: SettingsViewProtocol?
    let viewModelFactory: SettingsViewModelFactoryProtocol
    let config: ApplicationConfigProtocol
    let interactor: SettingsInteractorInputProtocol
    let wireframe: SettingsWireframeProtocol
    let logger: LoggerProtocol?

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
            locale: locale
        )
        view?.reload(sections: sectionViewModels)
    }

    private func show(url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }
}

extension SettingsPresenter: SettingsPresenterProtocol {
    var appNameText: String {
        "\(config.appName) \(config.version)"
    }

    func setup() {
        updateView()

        interactor.setup()
    }

    func actionRow(_ row: SettingsRow) {
        switch row {
        case .wallets:
            wireframe.showAccountSelection(from: view)
        case .language:
            wireframe.showLanguageSelection(from: view)
        case .changePin:
            wireframe.showPincodeChange(from: view)
        case .telegram:
            show(url: config.socialURL)
        case .twitter:
            show(url: config.twitterURL)
        case .rateUs:
            // TODO:
            show(url: config.websiteURL)
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
}

extension SettingsPresenter: SettingsInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        if let icon = viewModelFactory.createWalletIcon(for: wallet.substrateAccountId) {
            view?.setWalletIcon(icon)
        }
        self.wallet = wallet
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive user data provider \(error)")

        let locale = localizationManager?.selectedLocale ?? Locale.current

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
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
