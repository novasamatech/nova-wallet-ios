import Foundation

final class DAppSearchPresenter {
    weak var view: DAppSearchViewProtocol?
    let wireframe: DAppSearchWireframeProtocol
    let interactor: DAppSearchInteractorInputProtocol

    private var dAppList: DAppList?

    private(set) var query: String?

    weak var delegate: DAppSearchDelegate?

    let viewModelFactory: DAppListViewModelFactoryProtocol

    init(
        interactor: DAppSearchInteractorInputProtocol,
        wireframe: DAppSearchWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        initialQuery: String?,
        delegate: DAppSearchDelegate
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        query = initialQuery
        self.delegate = delegate
    }

    private func provideViewModel() {
        if let dAppList = dAppList {
            let viewModels = viewModelFactory.createDAppsFromQuery(query, dAppList: dAppList)
            view?.didReceiveDApp(viewModels: viewModels)
        } else {
            view?.didReceiveDApp(viewModels: [])
        }
    }
}

extension DAppSearchPresenter: DAppSearchPresenterProtocol {
    func setup() {
        if let query = query {
            view?.didReceive(initialQuery: query)
        }

        interactor.setup()
    }

    func updateSearch(query: String) {
        self.query = query

        provideViewModel()
    }

    func selectDApp(viewModel _: DAppViewModel) {}

    func selectSearchQuery() {
        delegate?.didCompleteDAppSearchQuery(query ?? "")
        wireframe.close(from: view)
    }
}

extension DAppSearchPresenter: DAppSearchInteractorOutputProtocol {
    func didReceive(dAppsResult: Result<DAppList?, Error>) {
        switch dAppsResult {
        case let .success(list):
            dAppList = list

            provideViewModel()
        case .failure:
            break
        }
    }
}
