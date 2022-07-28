import Foundation
import CommonWallet

final class OperationDetailsCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let txData: AssetTransactionData
    let chainAsset: ChainAsset

    init(
        commandFactory: WalletCommandFactoryProtocol,
        txData: AssetTransactionData,
        chainAsset: ChainAsset
    ) {
        self.commandFactory = commandFactory
        self.txData = txData
        self.chainAsset = chainAsset
    }

    func execute() throws {
        guard let view = OperationDetailsViewFactory.createView(
            for: txData,
            chainAsset: chainAsset,
            commandFactory: commandFactory
        ) else {
            return
        }

        let presentationCommand = commandFactory?.preparePresentationCommand(for: view.controller)
        presentationCommand?.presentationStyle = .modal(inNavigation: true)

        try presentationCommand?.execute()
    }
}
