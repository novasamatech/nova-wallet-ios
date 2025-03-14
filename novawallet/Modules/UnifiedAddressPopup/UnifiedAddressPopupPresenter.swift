import Foundation
import SoraFoundation

final class UnifiedAddressPopupPresenter {
    weak var view: UnifiedAddressPopupViewProtocol?
    let wireframe: UnifiedAddressPopupWireframeProtocol
    let interactor: UnifiedAddressPopupInteractorInputProtocol
    let viewModelFactory: UnifiedAddressPopup.ViewModelFactory
    let localizationManager: LocalizationManagerProtocol

    var dontShowAgain: Bool?

    init(
        interactor: UnifiedAddressPopupInteractorInputProtocol,
        wireframe: UnifiedAddressPopupWireframeProtocol,
        viewModelFactory: UnifiedAddressPopup.ViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: Private

private extension UnifiedAddressPopupPresenter {
    func provideViewModel() {
        guard let dontShowAgain else { return }

        let viewModel = viewModelFactory.createViewModel(
            dontShowAgain: dontShowAgain,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel)
    }
}

// MARK: UnifiedAddressPopupPresenterProtocol

extension UnifiedAddressPopupPresenter: UnifiedAddressPopupPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

// MARK: UnifiedAddressPopupInteractorOutputProtocol

extension UnifiedAddressPopupPresenter: UnifiedAddressPopupInteractorOutputProtocol {
    func didReceiveDontShow(_ value: Bool) {
        guard dontShowAgain != value else { return }

        dontShowAgain = value
        provideViewModel()
    }
}
