import Foundation

final class ReferendumFullDescriptionPresenter {
    weak var view: ReferendumFullDescriptionViewProtocol?
    let wireframe: ReferendumFullDescriptionWireframeProtocol
    let interactor: ReferendumFullDescriptionInteractorInputProtocol

    let title: String
    let description: String

    init(
        title: String,
        description: String,
        interactor: ReferendumFullDescriptionInteractorInputProtocol,
        wireframe: ReferendumFullDescriptionWireframeProtocol
    ) {
        self.title = title
        self.description = description
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ReferendumFullDescriptionPresenter: ReferendumFullDescriptionPresenterProtocol {
    func setup() {
        view?.didReceive(title: title, description: description)
    }

    func open(url: URL) {
        guard let view = view else {
            return
        }

        wireframe.showWeb(
            url: url,
            from: view,
            style: .modal
        )
    }
}

extension ReferendumFullDescriptionPresenter: ReferendumFullDescriptionInteractorOutputProtocol {}
