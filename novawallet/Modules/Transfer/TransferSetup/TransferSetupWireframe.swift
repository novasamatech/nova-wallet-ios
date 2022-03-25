import Foundation
import CommonWallet

final class TransferSetupWireframe: TransferSetupWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showConfirmation(
        from _: TransferSetupViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmViewFactory.createView(
            chainAsset: chainAsset,
            recepient: recepient,
            amount: sendingAmount
        ) else {
            return
        }

        let command = commandFactory?.preparePresentationCommand(for: confirmView.controller)
        command?.presentationStyle = .push(hidesBottomBar: true)
        try? command?.execute()
    }

    func showRecepientScan(from _: TransferSetupViewProtocol?) {
        // TODO:
    }
}
