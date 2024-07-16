protocol CustomNetworkBaseInteractorInputProtocol: AnyObject {
    func setup()
    func modify(with request: CustomNetwork.ModifyRequest)
}

protocol CustomNetworkAddInteractorInputProtocol: CustomNetworkBaseInteractorInputProtocol {
    func addNetwork(with request: CustomNetwork.AddRequest)
    func fetchNetworkProperties(for url: String)
}

protocol CustomNetworkEditInteractorInputProtocol: CustomNetworkBaseInteractorInputProtocol {
    func editNetwork(with request: CustomNetwork.EditRequest)
}
