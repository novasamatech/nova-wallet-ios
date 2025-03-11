import Foundation

final class SelectRampProviderPresenter {
    weak var view: SelectRampProviderViewProtocol?
    let wireframe: SelectRampProviderWireframeProtocol
    let interactor: SelectRampProviderInteractorInputProtocol

    init(
        interactor: SelectRampProviderInteractorInputProtocol,
        wireframe: SelectRampProviderWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SelectRampProviderPresenter: SelectRampProviderPresenterProtocol {
    func setup() {}
}

extension SelectRampProviderPresenter: SelectRampProviderInteractorOutputProtocol {}
