protocol ReferendumSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: TableSearchResultViewModel<ReferendumsCellViewModel>)
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
}

protocol ReferendumSearchPresenterProtocol: TableSearchPresenterProtocol {
    func setup()
    func select(referendumIndex: UInt)
    func cancel()
}

protocol ReferendumSearchWireframeProtocol: AnyObject, AlertPresentable, CommonRetryable {
    func finish(from view: ControllerBackedProtocol?)
}

protocol ReferendumSearchDelegate: AnyObject {
    func didSelectReferendum(referendumIndex: ReferendumIdLocal)
}

enum ReferendumSearchError: Error {
    case searchFailed(String, Error)
}
