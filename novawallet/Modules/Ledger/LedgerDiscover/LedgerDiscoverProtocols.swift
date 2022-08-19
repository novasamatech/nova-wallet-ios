import Foundation

protocol LedgerDiscoverViewProtocol: ControllerBackedProtocol {
    func didReceive(devices: [String])
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
}

protocol LedgerDiscoverWireframeProtocol: AnyObject {}
