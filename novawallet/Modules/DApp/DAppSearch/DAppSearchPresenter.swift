import Foundation

final class DAppSearchPresenter {
    weak var view: DAppSearchViewProtocol?
    let wireframe: DAppSearchWireframeProtocol

    private(set) var query: String?

    weak var delegate: DAppSearchDelegate?

    let logger: LoggerProtocol?

    init(
        wireframe: DAppSearchWireframeProtocol,
        initialQuery: String?,
        delegate: DAppSearchDelegate,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        query = initialQuery
        self.delegate = delegate
        self.logger = logger
    }
}

extension DAppSearchPresenter: DAppSearchPresenterProtocol {
    func setup() {
        if let query = query {
            view?.didReceive(initialQuery: query)
        }
    }

    func updateSearch(query: String) {
        self.query = query
    }

    func selectSearchQuery() {
        delegate?.didCompleteDAppSearchResult(.query(string: query ?? ""))
        wireframe.close(from: view)
    }

    func cancel() {
        wireframe.close(from: view)
    }
}
