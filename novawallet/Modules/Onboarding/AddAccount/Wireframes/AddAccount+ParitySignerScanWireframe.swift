import Foundation

extension AddAccount {
    final class ParitySignerScanWireframe: ParitySignerScanWireframeProtocol {
        func completeScan(
            on view: ControllerBackedProtocol?,
            addressScan: ParitySignerAddressScan,
            type: ParitySignerType,
            mode _: ParitySignerWelcomeMode
        ) {
            guard
                let addressesView = ParitySignerAddressesViewFactory.createAddAccountView(
                    with: addressScan,
                    type: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
        }
    }
}
