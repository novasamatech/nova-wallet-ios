import Foundation

protocol SwapTokenSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(title: String)
    func didReceive(chips: [SwapTokenSelectChipViewModel])
    func didReceive(list: SwapTokenSelectListViewModel)
    func didResetChipsScroll()
}

protocol SwapTokenSelectPresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func selectChip(_ kind: SwapTokenSelectChipViewModel.Kind)
    func selectToken(with chainAssetId: ChainAssetId)
    func close()
}

protocol SwapTokenSelectInteractorInputProtocol: AnyObject {
    func setup()
    func refreshRoutes()
    func save(networks: [ChainModel.Id])
}

protocol SwapTokenSelectInteractorOutputProtocol: AnyObject {
    func didReceive(assetList: AssetListModel)
    func didReceive(routeUniverse: Set<ChainAssetId>)
    func didReceive(swappable: Set<ChainAssetId>)
    func didReceive(savedNetworks: [ChainModel.Id])
    func didReceive(error: SwapTokenSelectError)
}

protocol SwapTokenSelectWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func close(view: SwapTokenSelectViewProtocol?)

    func showNetworkSelection(
        from view: SwapTokenSelectViewProtocol?,
        viewModels: [SwapTokenSelectNetworkViewModel],
        completion: @escaping ([ChainModel.Id]) -> Void
    )
}

enum SwapTokenSelectError: Error {
    case routes(Error)
}
