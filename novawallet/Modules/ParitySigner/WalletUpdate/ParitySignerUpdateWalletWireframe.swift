import Foundation

final class ParitySignerUpdateWalletWireframe: ParitySignerAddressesWireframeProtocol {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        walletUpdate _: PolkadotVaultWalletUpdate,
        type _: ParitySignerType
    ) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
