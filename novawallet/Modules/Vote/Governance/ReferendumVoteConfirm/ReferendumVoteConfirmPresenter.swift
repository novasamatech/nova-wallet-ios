import Foundation

final class ReferendumVoteConfirmPresenter {
    weak var view: ReferendumVoteConfirmViewProtocol?
    let wireframe: ReferendumVoteConfirmWireframeProtocol
    let interactor: ReferendumVoteConfirmInteractorInputProtocol

    init(
        interactor: ReferendumVoteConfirmInteractorInputProtocol,
        wireframe: ReferendumVoteConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ReferendumVoteConfirmPresenter: ReferendumVoteConfirmPresenterProtocol {
    func setup() {}
}

extension ReferendumVoteConfirmPresenter: ReferendumVoteConfirmInteractorOutputProtocol {}
