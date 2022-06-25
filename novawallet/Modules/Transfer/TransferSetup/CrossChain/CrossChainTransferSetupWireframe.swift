import Foundation
import CommonWallet

final class CrossChainTransferSetupWireframe: CrossChainTransferSetupWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showConfirmation(
        from _: TransferSetupChildViewProtocol?,
        originChainAsset _: ChainAsset,
        destinationChainAsset _: ChainAsset,
        sendingAmount _: Decimal,
        recepient _: AccountAddress
    ) {}
}
