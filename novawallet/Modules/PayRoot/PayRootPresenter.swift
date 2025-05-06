import Foundation

final class PayRootPresenter {
    weak var view: PayRootViewProtocol?
    let wireframe: PayRootWireframeProtocol
    let interactor: PayRootInteractorInputProtocol

    init(
        interactor: PayRootInteractorInputProtocol,
        wireframe: PayRootWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension PayRootPresenter: PayRootPresenterProtocol {
    func setup() {}
}

extension PayRootPresenter: PayRootInteractorOutputProtocol {}
