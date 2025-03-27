import Foundation

final class RampPresenter {
    weak var view: RampViewProtocol?
    var wireframe: RampWireframeProtocol!
    var interactor: RampInteractorInputProtocol!
}

extension RampPresenter: RampPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension RampPresenter: RampInteractorOutputProtocol {
    func didCompleteOperation(action: RampAction) {
        wireframe.complete(from: view, with: action.type)
    }
}
