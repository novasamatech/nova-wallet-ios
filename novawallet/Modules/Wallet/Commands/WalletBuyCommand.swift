import Foundation
import CommonWallet

final class WalletBuyCommand: WalletCommandProtocol {
    let action: PurchaseAction
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(action: PurchaseAction, commandFactory: WalletCommandFactoryProtocol) {
        self.action = action
        self.commandFactory = commandFactory
    }

    func execute() throws {}
}
