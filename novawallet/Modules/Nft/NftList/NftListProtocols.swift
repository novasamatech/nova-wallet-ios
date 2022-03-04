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

    func selectNft(at index: Int)
}

protocol NftListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func getNftForId(_ identifier: NftModel.Id)
}

protocol NftListInteractorOutputProtocol: AnyObject {
    func didReceiveNft(_ model: NftChainModel)
    func didReceiveNft(changes: [DataProviderChange<NftChainModel>])
    func didReceive(error: Error)
}

protocol NftListWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showNftDetails(from view: NftListViewProtocol?, model: NftChainModel)
}
