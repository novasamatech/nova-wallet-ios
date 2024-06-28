protocol CustomNetworkBaseInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CustomNetworkAddInteractorInputProtocol: CustomNetworkBaseInteractorInputProtocol {
    func addNetwork(
        networkType: ChainType,
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    )
}

protocol CustomNetworkEditInteractorInputProtocol: CustomNetworkBaseInteractorInputProtocol {
    func editNetwork(
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    )
}
