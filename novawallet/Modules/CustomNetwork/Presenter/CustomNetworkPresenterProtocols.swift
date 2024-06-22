protocol CustomNetworkPresenterProtocol: AnyObject {
    func setup()
    func handlePartial(url: String)
    func handlePartial(name: String)
    func handlePartial(currencySymbol: String)
    func handlePartial(blockExplorerURL: String)
    func handlePartial(coingeckoURL: String)
    func confirm()
}

protocol CustomNetworkAddPresenterProtocol {
    func switchNetworkType(selected segmentIndex: Int)
}

protocol CustomNetworkBaseInteractorOutputProtocol: AnyObject {
    func didReceive(_ error: Error)
}

protocol CustomNetworkAddInteractorOutputProtocol: CustomNetworkBaseInteractorOutputProtocol {
    func didAddChain()
}

protocol CustomNetworkEditInteractorOutputProtocol: CustomNetworkBaseInteractorOutputProtocol {
    func didEditNode()
    func didReceive(chain: ChainModel)
}