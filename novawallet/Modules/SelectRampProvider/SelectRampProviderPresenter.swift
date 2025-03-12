import Foundation
import SoraFoundation

final class SelectRampProviderPresenter {
    weak var view: SelectRampProviderViewProtocol?
    let wireframe: SelectRampProviderWireframeProtocol
    let interactor: SelectRampProviderInteractorInputProtocol
    let viewModelFactory: SelectRampProviderViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    let assetSymbol: AssetModel.Symbol
    let providerType: SelectRampProvider.ProviderType

    var rampActions: [RampAction]?

    init(
        interactor: SelectRampProviderInteractorInputProtocol,
        wireframe: SelectRampProviderWireframeProtocol,
        viewModelFactory: SelectRampProviderViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        assetSymbol: AssetModel.Symbol,
        providerType: SelectRampProvider.ProviderType
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.assetSymbol = assetSymbol
        self.providerType = providerType
    }
}

// MARK: Private

private extension SelectRampProviderPresenter {
    func provideViewModel() {
        guard let rampActions else { return }

        let viewModel = viewModelFactory.createViewModel(
            for: providerType,
            assetSymbol: assetSymbol,
            actions: rampActions,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel)
    }
}

// MARK: SelectRampProviderPresenterProtocol

extension SelectRampProviderPresenter: SelectRampProviderPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

// MARK: SelectRampProviderInteractorOutputProtocol

extension SelectRampProviderPresenter: SelectRampProviderInteractorOutputProtocol {
    func didReceive(_ rampActions: [RampAction]) {
        self.rampActions = rampActions

        provideViewModel()
    }
}
