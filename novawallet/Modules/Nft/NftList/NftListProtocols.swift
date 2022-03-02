import RobinHood

protocol NftListViewProtocol: ControllerBackedProtocol {
    func didReceive(changes: [ListDifference<NftListViewModel>])
    func didCompleteRefreshing()
}

protocol NftListPresenterProtocol: AnyObject {
    func setup()
    func refresh()

    func numberOfItems() -> Int
    func nft(at index: Int) -> NftListViewModel
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
