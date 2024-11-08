import Foundation

final class AssetOperationNetworkListWireframe: AssetOperationNetworkListWireframeProtocol {
    private let transferCompletion: TransferCompletionClosure?

    init(transferCompletion: TransferCompletionClosure? = nil) {
        self.transferCompletion = transferCompletion
    }

    func showSend(
        from view: ControllerBackedProtocol?,
        for chainAsset: ChainAsset
    ) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil,
            transferCompletion: transferCompletion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            transferSetupView.controller,
            animated: true
        )
    }
}
