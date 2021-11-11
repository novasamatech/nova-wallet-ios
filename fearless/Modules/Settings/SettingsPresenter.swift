import Foundation
import SoraFoundation

final class SettingsPresenter {
    weak var view: SettingsViewProtocol?
    let viewModelFactory: SettingsViewModelFactoryProtocol
    private(set) var userSettings: UserSettings?
    let interactor: SettingsInteractorInputProtocol
    let wireframe: SettingsWireframeProtocol
    let logger: LoggerProtocol?

    init(
        viewModelFactory: SettingsViewModelFactoryProtocol,
        interactor: SettingsInteractorInputProtocol,
        wireframe: SettingsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol?,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
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
}

extension SettingsPresenter: SettingsPresenterProtocol {
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
            wireframe.showAbout(from: view)
        case .twitter:
            wireframe.showAbout(from: view)
        case .rateUs:
            wireframe.showAbout(from: view)
        case .website:
            wireframe.showAbout(from: view)
        case .github:
            wireframe.showAbout(from: view)
        case .terms:
            wireframe.showAbout(from: view)
        case .privacyPolicy:
            wireframe.showAbout(from: view)
        }
    }
}

extension SettingsPresenter: SettingsInteractorOutputProtocol {
    func didReceive(userSettings: UserSettings) {
        self.userSettings = userSettings
        updateView()
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
