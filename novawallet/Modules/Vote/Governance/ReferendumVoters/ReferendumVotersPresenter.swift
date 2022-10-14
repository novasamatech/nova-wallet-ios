import Foundation

final class ReferendumVotersPresenter {
    weak var view: ReferendumVotersViewProtocol?
    let wireframe: ReferendumVotersWireframeProtocol
    let interactor: ReferendumVotersInteractorInputProtocol

    init(
        interactor: ReferendumVotersInteractorInputProtocol,
        wireframe: ReferendumVotersWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ReferendumVotersPresenter: ReferendumVotersPresenterProtocol {
    func setup() {}
}

extension ReferendumVotersPresenter: ReferendumVotersInteractorOutputProtocol {}