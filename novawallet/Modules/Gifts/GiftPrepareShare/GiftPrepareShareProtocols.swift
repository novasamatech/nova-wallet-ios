protocol GiftPrepareShareViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftPrepareViewModel)
}

protocol GiftPrepareSharePresenterProtocol: AnyObject {
    func setup()
}

protocol GiftPrepareShareInteractorInputProtocol: AnyObject {}

protocol GiftPrepareShareInteractorOutputProtocol: AnyObject {}

protocol GiftPrepareShareWireframeProtocol: AnyObject {}
