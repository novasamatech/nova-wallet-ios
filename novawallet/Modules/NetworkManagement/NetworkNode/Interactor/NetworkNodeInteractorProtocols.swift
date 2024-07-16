protocol NetworkNodeBaseInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NetworkNodeAddInteractorInputProtocol: NetworkNodeBaseInteractorInputProtocol {
    func addNode(
        with url: String,
        name: String
    )
}

protocol NetworkNodeEditInteractorInputProtocol: NetworkNodeBaseInteractorInputProtocol {
    func editNode(
        with url: String,
        name: String
    )
}
