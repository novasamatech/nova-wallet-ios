import Foundation
import CommonWallet

final class OperationDetailsWireframe: OperationDetailsWireframeProtocol {
    func showSend(
        from _: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    ) {
        guard let transferView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: displayAddress
        ) else {
            return
        }

        // TODO: Remove wireframe
//        let command = commandFactory?.preparePresentationCommand(for: transferView.controller)
//        command?.presentationStyle = .push(hidesBottomBar: true)
//        try? command?.execute()
    }
}
