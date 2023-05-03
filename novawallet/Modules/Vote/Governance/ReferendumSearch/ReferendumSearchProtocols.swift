protocol ReferendumSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: TableSearchResultViewModel<ReferendumsCellViewModel>)
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
}

protocol ReferendumSearchPresenterProtocol: TableSearchPresenterProtocol {
    func setup()
    func cancel()
}

protocol ReferendumSearchInteractorInputProtocol: BaseReferendumsInteractorInputProtocol {
    func search(text: String)
}

protocol ReferendumSearchInteractorOutputProtocol: BaseReferendumsInteractorOutputProtocol {
    func didRecieveChain(_ chainModel: ChainModel)
    func didReceiveReferendumsMetadata(_ referendumsMetadata: ReferendumMetadataMapping?)
}

protocol ReferendumSearchWireframeProtocol: AnyObject {
    func finish(from view: ControllerBackedProtocol?)
}
