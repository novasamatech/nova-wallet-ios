protocol LedgerDiscoverViewProtocol: ControllerBackedProtocol {}

protocol LedgerDiscoverPresenterProtocol: AnyObject {
    func setup()
}

protocol LedgerDiscoverInteractorInputProtocol: AnyObject {
    func setup()
}

protocol LedgerDiscoverInteractorOutputProtocol: AnyObject {
    func didDiscover(device: LedgerDeviceProtocol)
}

protocol LedgerDiscoverWireframeProtocol: AnyObject {}
