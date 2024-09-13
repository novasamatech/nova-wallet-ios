import Foundation

final class SwipeGovVotingListPresenter {
    weak var view: SwipeGovVotingListViewProtocol?
    let wireframe: SwipeGovVotingListWireframeProtocol
    let interactor: SwipeGovVotingListInteractorInputProtocol

    init(
        interactor: SwipeGovVotingListInteractorInputProtocol,
        wireframe: SwipeGovVotingListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwipeGovVotingListPresenter: SwipeGovVotingListPresenterProtocol {
    func setup() {}
}

extension SwipeGovVotingListPresenter: SwipeGovVotingListInteractorOutputProtocol {}