import Foundation

extension AddAccount {
    final class ParitySignerScanWireframe: ParitySignerScanWireframeProtocol {
        func completeScan(on view: ControllerBackedProtocol?, addressScan: ParitySignerAddressScan) {
            guard
                let addressesView = ParitySignerAddressesViewFactory.createAddAccountView(
                    with: addressScan
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
        }
    }
}
