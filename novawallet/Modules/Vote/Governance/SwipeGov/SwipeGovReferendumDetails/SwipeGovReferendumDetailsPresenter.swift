import Foundation

final class SwipeGovReferendumDetailsPresenter {
    weak var view: SwipeGovReferendumDetailsViewProtocol?
    let wireframe: SwipeGovReferendumDetailsWireframeProtocol
    let interactor: SwipeGovReferendumDetailsInteractorInputProtocol

    init(
        interactor: SwipeGovReferendumDetailsInteractorInputProtocol,
        wireframe: SwipeGovReferendumDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwipeGovReferendumDetailsPresenter: SwipeGovReferendumDetailsPresenterProtocol {
    func setup() {}
}

extension SwipeGovReferendumDetailsPresenter: SwipeGovReferendumDetailsInteractorOutputProtocol {}