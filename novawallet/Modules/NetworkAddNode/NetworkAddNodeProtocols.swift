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

protocol NetworkAddNodeInteractorInputProtocol: AnyObject {}

protocol NetworkAddNodeInteractorOutputProtocol: AnyObject {}

protocol NetworkAddNodeWireframeProtocol: AnyObject {}
