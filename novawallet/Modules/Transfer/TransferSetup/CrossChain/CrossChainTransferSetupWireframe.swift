import Foundation
import CommonWallet

final class CrossChainTransferSetupWireframe: CrossChainTransferSetupWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let xcmTransfers: XcmTransfers

    init(xcmTransfers: XcmTransfers) {
        self.xcmTransfers = xcmTransfers
    }

    func showConfirmation(
        from _: TransferSetupChildViewProtocol?,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmCrossChainViewFactory.createView(
            originChainAsset: originChainAsset,
            destinationAsset: destinationChainAsset,
            xcmTransfers: xcmTransfers,
            recepient: recepient,
            amount: sendingAmount
        ) else {
            return
        }

        let command = commandFactory?.preparePresentationCommand(for: confirmView.controller)
        command?.presentationStyle = .push(hidesBottomBar: true)
        try? command?.execute()
    }
}
