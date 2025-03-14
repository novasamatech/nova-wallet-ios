import Foundation

final class UnifiedAddressPopupPresenter {
    weak var view: UnifiedAddressPopupViewProtocol?
    let wireframe: UnifiedAddressPopupWireframeProtocol
    let interactor: UnifiedAddressPopupInteractorInputProtocol

    init(
        interactor: UnifiedAddressPopupInteractorInputProtocol,
        wireframe: UnifiedAddressPopupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension UnifiedAddressPopupPresenter: UnifiedAddressPopupPresenterProtocol {
    func setup() {}
}

extension UnifiedAddressPopupPresenter: UnifiedAddressPopupInteractorOutputProtocol {}