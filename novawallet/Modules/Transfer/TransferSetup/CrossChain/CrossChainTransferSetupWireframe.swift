import Foundation
import CommonWallet

final class CrossChainTransferSetupWireframe: CrossChainTransferSetupWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let xcmTransfers: XcmTransfers

    init(xcmTransfers: XcmTransfers) {
        self.xcmTransfers = xcmTransfers
    }

    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
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
