protocol AssetsSearchViewProtocol: ControllerBackedProtocol {}

protocol AssetsSearchPresenterProtocol: AnyObject {
    func setup()
}

protocol AssetsSearchInteractorInputProtocol: WalletListBaseInteractorInputProtocol {}

protocol AssetsSearchInteractorOutputProtocol: WalletListBaseInteractorOutputProtocol {}

protocol AssetsSearchWireframeProtocol: AnyObject {}
