import Foundation
import CommonWallet

final class OperationDetailsWireframe: OperationDetailsWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showSend(
        from _: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    ) {
        guard let transferView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: displayAddress,
            commandFactory: commandFactory
        ) else {
            return
        }

        let command = commandFactory?.preparePresentationCommand(for: transferView.controller)
        command?.presentationStyle = .push(hidesBottomBar: true)
        try? command?.execute()
    }
}
