import Foundation

final class PolkadotVaultScanWireframe: PolkadotVaultScanWireframeProtocol {
    func completeScan(
        on view: ControllerBackedProtocol?,
        accountScan _: PolkadotVaultAccountScan,
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
