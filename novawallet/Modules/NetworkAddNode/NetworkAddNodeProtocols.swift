import SoraFoundation

protocol NetworkAddNodeViewProtocol: ControllerBackedProtocol {
    func didReceiveUrl(viewModel: InputViewModelProtocol)
    func didReceiveName(viewModel: InputViewModelProtocol)
    func didReceiveChain(viewModel: NetworkViewModel)
    func setLoading(_ loading: Bool)
}

protocol NetworkAddNodePresenterProtocol: AnyObject {
    func setup()
    func handlePartial(url: String)
    func handlePartial(name: String)
    func confirmAddNode()
}

protocol NetworkAddNodeInteractorInputProtocol: AnyObject {
    func setup()
    
    func addNode(
        with url: String,
        name: String
    )
}

protocol NetworkAddNodeInteractorOutputProtocol: AnyObject {
    func didReceive(_ chain: ChainModel)
    func didReceive(_ error: Error)
    func didAddNode()
}

protocol NetworkAddNodeWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showNetworkDetails(from view: NetworkAddNodeViewProtocol?)
}
