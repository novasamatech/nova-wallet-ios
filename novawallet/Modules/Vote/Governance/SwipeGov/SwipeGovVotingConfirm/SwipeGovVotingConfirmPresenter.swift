import Foundation

final class SwipeGovVotingConfirmPresenter {
    weak var view: SwipeGovVotingConfirmViewProtocol?
    let wireframe: SwipeGovVotingConfirmWireframeProtocol
    let interactor: SwipeGovVotingConfirmInteractorInputProtocol

    init(
        interactor: SwipeGovVotingConfirmInteractorInputProtocol,
        wireframe: SwipeGovVotingConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwipeGovVotingConfirmPresenter: SwipeGovVotingConfirmPresenterProtocol {
    func setup() {}
}

extension SwipeGovVotingConfirmPresenter: SwipeGovVotingConfirmInteractorOutputProtocol {}