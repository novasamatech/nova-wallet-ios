import Foundation

final class PVScanWireframe: PVScanWireframeProtocol {
    func completeScan(
        on view: ControllerBackedProtocol?,
        account: PolkadotVaultAccount,
        type: ParitySignerType
    ) {
        guard
            let addressesView = PVAddressesViewFactory.createOnboardingView(
                with: account,
                type: type
            )
        else { return }

        view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
    }
}
