import Foundation

protocol LedgerDiscoverViewProtocol: ControllerBackedProtocol {
    func didReceive(devices: [String])
    func didStartLoading(at index: Int)
    func didStopLoading(at index: Int)
}

protocol LedgerDiscoverPresenterProtocol: AnyObject {
    func setup()
    func selectDevice(at index: Int)
}

protocol LedgerDiscoverInteractorInputProtocol: AnyObject {
    func setup()
    func connect(to deviceId: UUID)
}

protocol LedgerDiscoverInteractorOutputProtocol: AnyObject {
    func didDiscover(device: LedgerDeviceProtocol)
    func didReceiveConnection(result: Result<Void, Error>, for deviceId: UUID)
    func didReceiveSetup(error: LedgerDiscoveryError)
}

protocol LedgerDiscoverWireframeProtocol: AlertPresentable, ErrorPresentable, ApplicationSettingsPresentable {
    func showAccountSelection(from view: LedgerDiscoverViewProtocol?, for deviceId: UUID)
}
