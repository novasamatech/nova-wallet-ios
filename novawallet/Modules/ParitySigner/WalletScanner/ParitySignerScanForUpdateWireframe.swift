import Foundation

final class ParitySignerScanForUpdateWireframe: ParitySignerScanWireframeProtocol {
    let wallet: MetaAccountModel

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func completeScan(
        on view: ControllerBackedProtocol?,
        walletUpdate: PolkadotVaultWalletUpdate,
        type _: ParitySignerType
    ) {
        guard
            let addressesView = ParitySignerUpdateWalletViewFactory.createView(
                for: wallet,
                update: walletUpdate
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
    }
}
