import Foundation
import SoraFoundation

final class ProfilePresenter {
    weak var view: ProfileViewProtocol?
    var interactor: ProfileInteractorInputProtocol!
    var wireframe: ProfileWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var viewModelFactory: ProfileViewModelFactoryProtocol

    private(set) var userSettings: UserSettings?
    private(set) var wallet: MetaAccountModel?

    init(viewModelFactory: ProfileViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func updateAccountViewModel() {
        guard let userSettings = userSettings else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let userDetailsViewModel = viewModelFactory.createUserViewModel(from: userSettings, locale: locale)
        view?.didLoad(userViewModel: userDetailsViewModel)
    }

    private func updateOptionsViewModel() {
        guard
            let userSettings = userSettings,
            let language = localizationManager?.selectedLanguage
        else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let optionViewModels = viewModelFactory.createOptionViewModels(
            from: userSettings,
            language: language,
            locale: locale
        )
        view?.didLoad(optionViewModels: optionViewModels)
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {
    func setup() {
        updateOptionsViewModel()

        interactor.setup()
    }

    func activateAccountDetails() {
        guard let wallet = self.wallet else { return }
        wireframe.showAccountDetails(for: wallet, from: view)
    }

    func activateOption(at index: UInt) {
        guard let option = ProfileOption(rawValue: index) else {
            return
        }

        switch option {
        case .accountList:
            wireframe.showAccountSelection(from: view)
        case .connectionList:
            wireframe.showConnectionSelection(from: view)
        case .changePincode:
            wireframe.showPincodeChange(from: view)
        case .language:
            wireframe.showLanguageSelection(from: view)
        case .about:
            wireframe.showAbout(from: view)
        }
    }
}

extension ProfilePresenter: ProfileInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func didReceive(userSettings: UserSettings) {
        self.userSettings = userSettings
        updateAccountViewModel()
        updateOptionsViewModel()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive user data provider \(error)")

        let locale = localizationManager?.selectedLocale ?? Locale.current

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
        }
    }
}

extension ProfilePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateAccountViewModel()
            updateOptionsViewModel()
        }
    }
}
