protocol NftListViewProtocol: ControllerBackedProtocol {}

protocol NftListPresenterProtocol: AnyObject {
    func setup()
}

protocol NftListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol NftListInteractorOutputProtocol: AnyObject {}

protocol NftListWireframeProtocol: AnyObject {}
