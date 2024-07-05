protocol CustomNetworkBaseInteractorInputProtocol: AnyObject {
    func setup()
    
    func modify(
        _ existingNetwork: ChainModel,
        node: ChainNodeModel,
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    )
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
