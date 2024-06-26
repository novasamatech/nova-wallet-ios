import Foundation

final class GenericLedgerDiscoverWireframe: LedgerDiscoverWireframeProtocol {
    init() {}

    func showAccountSelection(from _: ControllerBackedProtocol?, device _: LedgerDeviceProtocol) {
        Logger.shared.info("Did select device")
    }
}
