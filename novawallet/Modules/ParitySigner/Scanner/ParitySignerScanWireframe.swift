import Foundation

final class ParitySignerScanWireframe: ParitySignerScanWireframeProtocol {
    func completeScan(on view: ControllerBackedProtocol?, addressScan: ParitySignerAddressScan) {
        guard let addressesView = ParitySignerAddressesViewFactory.createView(with: addressScan) else {
            return
        }

        view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
    }
}
