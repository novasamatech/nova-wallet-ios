import Foundation

final class DAppListPresenter {
    weak var view: DAppListViewProtocol?
    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol

    init(
        interactor: DAppListInteractorInputProtocol,
        wireframe: DAppListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DAppListPresenter: DAppListPresenterProtocol {
    func setup() {}
}

extension DAppListPresenter: DAppListInteractorOutputProtocol {}