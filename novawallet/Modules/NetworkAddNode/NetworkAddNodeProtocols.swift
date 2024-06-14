import SoraFoundation

protocol NetworkAddNodeViewProtocol: ControllerBackedProtocol {
    func didReceiveUrl(viewModel: InputViewModelProtocol)
    func didReceiveName(viewModel: InputViewModelProtocol)
}

protocol NetworkAddNodePresenterProtocol: AnyObject {
    func setup()
    func handlePartial(url: String)
    func handlePartial(name: String)
    func confirmAddNode()
}

protocol NetworkAddNodeInteractorInputProtocol: AnyObject {
    func addNode(
        with url: String,
        name: String
    )
}

protocol NetworkAddNodeInteractorOutputProtocol: AnyObject {
    func didReceive(_ error: Error)
    func didAddNode()
}

protocol NetworkAddNodeWireframeProtocol: AnyObject {}
