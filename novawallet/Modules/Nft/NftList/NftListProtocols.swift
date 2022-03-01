import RobinHood

protocol NftListViewProtocol: ControllerBackedProtocol {}

protocol NftListPresenterProtocol: AnyObject {
    func setup()
}

protocol NftListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol NftListInteractorOutputProtocol: AnyObject {
    func didReceiveNft(changes: [DataProviderChange<NftChainModel>])
    func didReceive(error: Error)
}

protocol NftListWireframeProtocol: AnyObject {}
