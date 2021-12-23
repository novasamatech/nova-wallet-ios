import Foundation

final class DAppSearchPresenter {
    weak var view: DAppSearchViewProtocol?
    let wireframe: DAppSearchWireframeProtocol
    let interactor: DAppSearchInteractorInputProtocol

    let initialQuery: String?

    weak var delegate: DAppSearchDelegate?

    init(
        interactor: DAppSearchInteractorInputProtocol,
        wireframe: DAppSearchWireframeProtocol,
        initialQuery: String?,
        delegate: DAppSearchDelegate
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.initialQuery = initialQuery
        self.delegate = delegate
    }
}

extension DAppSearchPresenter: DAppSearchPresenterProtocol {
    func setup() {
        if let initialQuery = initialQuery {
            view?.didReceive(initialQuery: initialQuery)
        }
    }

    func activateSearch(for input: String) {
        delegate?.didCompleteDAppSearchQuery(input)
        wireframe.close(from: view)
    }
}

extension DAppSearchPresenter: DAppSearchInteractorOutputProtocol {}
