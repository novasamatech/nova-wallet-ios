import Foundation

final class ParitySignerScanWireframe: ParitySignerScanWireframeProtocol {
    func completeScan(
        on view: ControllerBackedProtocol?,
        addressScan: ParitySignerAddressScan,
        type: ParitySignerType
    ) {
        guard
            let addressesView = ParitySignerAddressesViewFactory.createOnboardingView(
                with: addressScan,
                type: type
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
    }
}
