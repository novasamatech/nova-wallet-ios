protocol NetworkNodePresenterProtocol: AnyObject {
    func setup()
    func handlePartial(url: String)
    func handlePartial(name: String)
    func confirm()
}

protocol NetworkNodeBaseInteractorOutputProtocol: AnyObject {
    func didReceive(_ chain: ChainModel)
    func didReceive(_ error: Error)
}

protocol NetworkNodeAddInteractorOutputProtocol: NetworkNodeBaseInteractorOutputProtocol {
    func didAddNode()
}

protocol NetworkNodeEditInteractorOutputProtocol: NetworkNodeBaseInteractorOutputProtocol {
    func didEditNode()
    func didReceive(node: ChainNodeModel)
}
