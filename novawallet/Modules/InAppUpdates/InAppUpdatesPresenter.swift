import Foundation

final class InAppUpdatesPresenter {
    weak var view: InAppUpdatesViewProtocol?
    let wireframe: InAppUpdatesWireframeProtocol
    let interactor: InAppUpdatesInteractorInputProtocol

    init(
        interactor: InAppUpdatesInteractorInputProtocol,
        wireframe: InAppUpdatesWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension InAppUpdatesPresenter: InAppUpdatesPresenterProtocol {
    func setup() {}
}

extension InAppUpdatesPresenter: InAppUpdatesInteractorOutputProtocol {}
