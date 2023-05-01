protocol ReferendumSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: TableSearchResultViewModel<ReferendumsCellViewModel>)
}

protocol ReferendumSearchPresenterProtocol: TableSearchPresenterProtocol {
    func setup()
}

protocol ReferendumSearchInteractorInputProtocol: BaseReferendumsInteractorInputProtocol {}

protocol ReferendumSearchInteractorOutputProtocol: BaseReferendumsInteractorOutputProtocol {
    func didRecieveChain(_ chainModel: ChainModel)
}

protocol ReferendumSearchWireframeProtocol: AnyObject {}
