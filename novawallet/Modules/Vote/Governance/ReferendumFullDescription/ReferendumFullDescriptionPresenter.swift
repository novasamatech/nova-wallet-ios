import Foundation

final class ReferendumFullDescriptionPresenter {
    weak var view: ReferendumFullDescriptionViewProtocol?
    let wireframe: ReferendumFullDescriptionWireframeProtocol
    let interactor: ReferendumFullDescriptionInteractorInputProtocol

    init(
        interactor: ReferendumFullDescriptionInteractorInputProtocol,
        wireframe: ReferendumFullDescriptionWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ReferendumFullDescriptionPresenter: ReferendumFullDescriptionPresenterProtocol {
    func setup() {}
}

extension ReferendumFullDescriptionPresenter: ReferendumFullDescriptionInteractorOutputProtocol {}
