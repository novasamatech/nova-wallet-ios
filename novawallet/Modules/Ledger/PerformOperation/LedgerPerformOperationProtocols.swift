import Foundation

protocol LedgerPerformOperationViewProtocol: ControllerBackedProtocol {
    func didReceive(networkName: String)
    func didReceive(devices: [String])
    func didStartLoading(at index: Int)
    func didStopLoading(at index: Int)
}

protocol LedgerPerformOperationPresenterProtocol: AnyObject {
    func setup()
    func selectDevice(at index: Int)
}

protocol LedgerPerformOperationInputProtocol: AnyObject {
    func setup()
    func performOperation(using deviceId: UUID)
}

protocol LedgerPerformOperationOutputProtocol: AnyObject {
    func didDiscover(device: LedgerDeviceProtocol)
    func didReceiveSetup(error: LedgerDiscoveryError)
}

protocol LedgerPerformOperationWireframeProtocol: AlertPresentable, ErrorPresentable,
    ApplicationSettingsPresentable,
    CommonRetryable,
    LedgerErrorPresentable {}
