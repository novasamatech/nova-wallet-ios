import Foundation
import CommonWallet

final class OnChainTransferSetupWireframe: OnChainTransferSetupWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmOnChainViewFactory.createView(
            chainAsset: chainAsset,
            recepient: recepient,
            amount: sendingAmount
        ) else {
            return
        }

        if let commandFactory = commandFactory {
            let command = commandFactory.preparePresentationCommand(for: confirmView.controller)
            command.presentationStyle = .push(hidesBottomBar: true)
            try? command.execute()
        } else {
            confirmView.controller.hidesBottomBarWhenPushed = true
            view?.controller.navigationController?.pushViewController(
                confirmView.controller,
                animated: true
            )
        }
    }
}
