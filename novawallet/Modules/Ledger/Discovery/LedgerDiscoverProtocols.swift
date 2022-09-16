import Foundation

protocol LedgerDiscoverInteractorOutputProtocol: LedgerPerformOperationOutputProtocol {
    func didReceiveConnection(result: Result<Void, Error>, for deviceId: UUID)
}

protocol LedgerDiscoverWireframeProtocol: LedgerPerformOperationWireframeProtocol {
    func showAccountSelection(from view: ControllerBackedProtocol?, chain: ChainModel, device: LedgerDeviceProtocol)
}
