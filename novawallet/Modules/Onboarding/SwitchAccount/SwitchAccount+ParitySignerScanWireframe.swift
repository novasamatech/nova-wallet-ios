import Foundation

extension SwitchAccount {
    final class ParitySignerScanWireframe: ParitySignerScanWireframeProtocol {
        func completeScan(
            on view: ControllerBackedProtocol?,
            addressScan: ParitySignerAddressScan,
            type: ParitySignerType,
            mode _: ParitySignerWelcomeMode
        ) {
            guard
                let addressesView = ParitySignerAddressesViewFactory.createSwitchAccountView(
                    with: addressScan,
                    type: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
        }
    }
}
