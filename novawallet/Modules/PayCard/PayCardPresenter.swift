import Foundation

final class PayCardPresenter {
    weak var view: PayCardViewProtocol?
    let wireframe: PayCardWireframeProtocol
    let interactor: PayCardInteractorInputProtocol

    init(
        interactor: PayCardInteractorInputProtocol,
        wireframe: PayCardWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension PayCardPresenter: PayCardPresenterProtocol {
    func setup() {}
}

extension PayCardPresenter: PayCardInteractorOutputProtocol {}
