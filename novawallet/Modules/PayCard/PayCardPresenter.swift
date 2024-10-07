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
    func setup() {
        interactor.setup()
    }

    func processMessage(body: Any, of name: String) {
        interactor.processMessage(body: body, of: name)
    }
}

extension PayCardPresenter: PayCardInteractorOutputProtocol {
    func didReceive(model: PayCardModel) {
        view?.didReceive(model: model)
    }

    func didRequestTopup(for model: PayCardTopupModel) {
        wireframe.showSend(from: view, with: model) { [weak self] _ in
        }
    }
}
