import Foundation

final class GiftAssetOperationWireframe: AssetOperationWireframe, GiftAssetOperationWireframeProtocol {
    private let transferCompletion: TransferCompletionClosure?
    private let buyTokensClosure: BuyTokensClosure?

    init(
        stateObservable: AssetListModelObservable,
        buyTokensClosure: BuyTokensClosure?,
        transferCompletion: TransferCompletionClosure?
    ) {
        self.buyTokensClosure = buyTokensClosure
        self.transferCompletion = transferCompletion

        super.init(stateObservable: stateObservable)
    }

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    ) {
        guard
            let buyTokensClosure,
            let transferCompletion,
            let selectNetworkView = AssetOperationNetworkListViewFactory.createGiftsView(
                with: multichainToken,
                stateObservable: stateObservable,
                transferCompletion: transferCompletion,
                buyTokensClosure: buyTokensClosure
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            selectNetworkView.controller,
            animated: true
        )
    }

    func showGiftTokens(from view: ControllerBackedProtocol?, chainAsset: ChainAsset) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil,
            transferCompletion: transferCompletion
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(transferSetupView.controller, animated: true)
    }
}

extension GiftAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
