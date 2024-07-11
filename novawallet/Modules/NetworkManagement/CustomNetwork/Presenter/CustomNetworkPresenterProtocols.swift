protocol CustomNetworkPresenterProtocol: AnyObject {
    func setup()
    func select(segment: ChainType?)
    func handlePartial(url: String)
    func handlePartial(name: String)
    func handlePartial(currencySymbol: String)
    func handlePartial(chainId: String)
    func handlePartial(blockExplorerURL: String)
    func handlePartial(coingeckoURL: String)
    func confirm()
}

protocol CustomNetworkAddPresenterProtocol {
    func switchNetworkType(selected segmentIndex: Int)
}

protocol CustomNetworkBaseInteractorOutputProtocol: AnyObject {
    func didFinishWorkWithNetwork()
    func didReceive(_ error: CustomNetworkBaseInteractorError)
    func didReceive(
        chain: ChainModel,
        selectedNode: ChainNodeModel
    )
}
