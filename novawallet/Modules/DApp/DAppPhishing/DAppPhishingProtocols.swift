protocol DAppPhishingViewDelegate: AnyObject {
    func dappPhishingViewDidHide()
}

protocol DAppPhishingViewProtocol: ControllerBackedProtocol {}

protocol DAppPhishingPresenterProtocol: AnyObject {
    func setup()
    func goBack()
}

protocol DAppPhishingWireframeProtocol: AnyObject {
    func complete(from view: DAppPhishingViewProtocol?)
}
