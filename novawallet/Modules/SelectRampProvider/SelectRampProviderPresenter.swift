import Foundation
import SoraFoundation

final class SelectRampProviderPresenter {
    weak var view: SelectRampProviderViewProtocol?
    let wireframe: SelectRampProviderWireframeProtocol
    let interactor: SelectRampProviderInteractorInputProtocol
    let viewModelFactory: SelectRampProviderViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    let chainAsset: ChainAsset
    let providerType: SelectRampProvider.ProviderType

    var rampActions: [RampAction]?

    init(
        interactor: SelectRampProviderInteractorInputProtocol,
        wireframe: SelectRampProviderWireframeProtocol,
        viewModelFactory: SelectRampProviderViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        chainAsset: ChainAsset,
        providerType: SelectRampProvider.ProviderType
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.chainAsset = chainAsset
        self.providerType = providerType
    }
}

// MARK: Private

private extension SelectRampProviderPresenter {
    func provideViewModel() {
        guard let rampActions else { return }

        let viewModel = viewModelFactory.createViewModel(
            for: providerType,
            asset: chainAsset.asset,
            actions: rampActions,
            locale: localizationManager.selectedLocale
        )
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
