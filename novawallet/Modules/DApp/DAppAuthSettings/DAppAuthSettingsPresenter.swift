import Foundation
import RobinHood
import SoraFoundation
import UIKit
import SubstrateSdk

final class DAppAuthSettingsPresenter {
    weak var view: DAppAuthSettingsViewProtocol?
    let wireframe: DAppAuthSettingsWireframeProtocol
    let interactor: DAppAuthSettingsInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol
    let viewModelFactory: DAppsAuthViewModelFactoryProtocol

    private lazy var iconGenerator = NovaIconGenerator()

    private(set) var authorizedDApps: [String: DAppSettings]?
    private(set) var dAppsList: DAppList?

    let wallet: MetaAccountModel

    init(
        wallet: MetaAccountModel,
        interactor: DAppAuthSettingsInteractorInputProtocol,
        wireframe: DAppAuthSettingsWireframeProtocol,
        viewModelFactory: DAppsAuthViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideWalletViewModel() {
        let iconModel = try? iconGenerator.generateFromAccountId(wallet.substrateAccountId)
        let iconViewModel = iconModel.map { DrawableIconViewModel(icon: $0) }

        let viewModel = DisplayWalletViewModel(
            name: wallet.name,
            imageViewModel: iconViewModel
        )

        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func provideAuthSettings() {
        guard let authorizedDApps = authorizedDApps else {
            return
        }

        let viewModels = viewModelFactory.createViewModels(from: authorizedDApps, dAppsList: dAppsList)
        view?.didReceiveAuthorized(viewModels: viewModels)
    }
}

extension DAppAuthSettingsPresenter: DAppAuthSettingsPresenterProtocol {
    func setup() {
        provideWalletViewModel()

        interactor.setup()
    }

    func remove(viewModel: DAppAuthSettingsViewModel) {
        guard let dAppSettings = authorizedDApps?[viewModel.identifier] else {
            return
        }

        let locale = localizationManager.selectedLocale

        wireframe.showAuthorizedRemovalConfirmation(
            from: view,
            name: viewModel.title,
            locale: locale
        ) { [weak self] in
            self?.interactor.remove(auth: dAppSettings)
        }
    }
}

extension DAppAuthSettingsPresenter: DAppAuthSettingsInteractorOutputProtocol {
    func didReceiveDAppList(_ list: DAppList?) {
        guard list != nil else {
            return
        }

        dAppsList = list

        provideAuthSettings()
    }

    func didReceiveAuthorizationSettings(changes: [DataProviderChange<DAppSettings>]) {
        authorizedDApps = changes.mergeToDict(authorizedDApps ?? [:])

        provideAuthSettings()
    }

    func didReceive(error: Error) {
        let locale = localizationManager.selectedLocale
        _ = wireframe.present(error: error, from: view, locale: locale)
    }
}
