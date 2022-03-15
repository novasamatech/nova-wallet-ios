import Foundation
import CommonWallet

final class OperationDetailsWireframe: OperationDetailsWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showSend(
        from _: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    ) {
        guard let commandFactory = commandFactory else {
            return
        }

        try? TransferSetupCommand(
            commandFactory: commandFactory,
            chainAsset: chainAsset,
            recepient: displayAddress
        ).execute()
    }
}
