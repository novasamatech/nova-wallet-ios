import Foundation
import Foundation_iOS

final class UnifiedAddressPopupPresenter {
    weak var view: UnifiedAddressPopupViewProtocol?
    let wireframe: UnifiedAddressPopupWireframeProtocol
    let interactor: UnifiedAddressPopupInteractorInputProtocol
    let viewModelFactory: UnifiedAddressPopup.ViewModelFactory
    let localizationManager: LocalizationManagerProtocol

    let newAddress: AccountAddress
    let legacyAddress: AccountAddress

    var dontShowAgain: Bool?

    init(
        interactor: UnifiedAddressPopupInteractorInputProtocol,
        wireframe: UnifiedAddressPopupWireframeProtocol,
        viewModelFactory: UnifiedAddressPopup.ViewModelFactory,
        newAddress: AccountAddress,
        legacyAddress: AccountAddress,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.newAddress = newAddress
        self.legacyAddress = legacyAddress
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

    func copyNewAddress() {
        wireframe.copyAddress(
            from: view,
            address: newAddress,
            locale: localizationManager.selectedLocale
        )
    }

    func copyLegacyAddress() {
        wireframe.copyAddress(
            from: view,
            address: legacyAddress,
            locale: localizationManager.selectedLocale
        )
    }

    func close() {
        wireframe.close(from: view)
    }

    func toggleHide() {
        guard let dontShowAgain else { return }

        interactor.setDontShow(!dontShowAgain)
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
