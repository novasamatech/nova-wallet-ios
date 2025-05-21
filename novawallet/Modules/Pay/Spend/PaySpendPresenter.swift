import Foundation

final class PaySpendPresenter {
    weak var view: PaySpendViewProtocol?
    let wireframe: PaySpendWireframeProtocol
    let interactor: PaySpendInteractorInputProtocol

    init(
        interactor: PaySpendInteractorInputProtocol,
        wireframe: PaySpendWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension PaySpendPresenter: PaySpendPresenterProtocol {
    func setup() {}
}

extension PaySpendPresenter: PaySpendInteractorOutputProtocol {}
