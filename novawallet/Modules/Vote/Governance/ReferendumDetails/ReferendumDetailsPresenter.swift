import Foundation

final class ReferendumDetailsPresenter {
    weak var view: ReferendumDetailsViewProtocol?
    let wireframe: ReferendumDetailsWireframeProtocol
    let interactor: ReferendumDetailsInteractorInputProtocol

    init(
        interactor: ReferendumDetailsInteractorInputProtocol,
        wireframe: ReferendumDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ReferendumDetailsPresenter: ReferendumDetailsPresenterProtocol {
    func setup() {}
}

extension ReferendumDetailsPresenter: ReferendumDetailsInteractorOutputProtocol {}
