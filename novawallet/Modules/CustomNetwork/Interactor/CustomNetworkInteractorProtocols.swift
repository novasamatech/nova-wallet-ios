protocol CustomNetworkBaseInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CustomNetworkAddInteractorInputProtocol: CustomNetworkBaseInteractorInputProtocol {
    func addNetwork(
        networkType: ,
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    )
}

protocol NetworkNodeEditInteractorInputProtocol: CustomNetworkBaseInteractorInputProtocol {
    func editNode(
        with url: String,
        name: String
    )
}
