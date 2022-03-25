import Foundation
import CommonWallet

final class TransferSetupCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let chainAsset: ChainAsset
    let recepient: DisplayAddress?

    init(
        commandFactory: WalletCommandFactoryProtocol,
        chainAsset: ChainAsset,
        recepient: DisplayAddress?
    ) {
        self.commandFactory = commandFactory
        self.chainAsset = chainAsset
        self.recepient = recepient
    }

    func execute() throws {
        guard let view = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: recepient,
            commandFactory: commandFactory
        ) else {
            return
        }

        let presentationCommand = commandFactory?.preparePresentationCommand(for: view.controller)
        presentationCommand?.presentationStyle = .modal(inNavigation: true)

        try presentationCommand?.execute()
    }
}
