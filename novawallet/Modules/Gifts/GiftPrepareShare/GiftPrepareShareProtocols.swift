protocol GiftPrepareShareViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GiftPrepareViewModel)
}

protocol GiftPrepareSharePresenterProtocol: AnyObject {
    func setup()
}

protocol GiftPrepareShareInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GiftPrepareShareInteractorOutputProtocol: AnyObject {
    func didReceive(_ gift: GiftModel)
}

protocol GiftPrepareShareWireframeProtocol: AnyObject {}
