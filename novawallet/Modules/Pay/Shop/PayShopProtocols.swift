protocol PayShopViewProtocol: ControllerBackedProtocol {}

protocol PayShopPresenterProtocol: AnyObject {
    func setup()
}

protocol PayShopInteractorInputProtocol: AnyObject {}

protocol PayShopInteractorOutputProtocol: AnyObject {}

protocol PayShopWireframeProtocol: AnyObject {}
