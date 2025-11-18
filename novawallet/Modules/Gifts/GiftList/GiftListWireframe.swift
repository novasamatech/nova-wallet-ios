import Foundation

final class GiftListWireframe {
    let stateObservable: AssetListModelObservable
    let transferCompletion: TransferCompletionClosure
    let buyTokensClosure: BuyTokensClosure

    init(
        stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) {
        self.stateObservable = stateObservable
        self.transferCompletion = transferCompletion
        self.buyTokensClosure = buyTokensClosure
    }
}

extension GiftListWireframe: GiftListWireframeProtocol {
    func showCreateGift(from view: (any ControllerBackedProtocol)?) {
        guard let assetOperationView = AssetOperationViewFactory.createGiftView(
            for: stateObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            assetOperationView.controller,
            animated: true
        )
    }

    func showGift(
        with id: GiftModel.Id,
        chainAsset: ChainAsset,
        from view: ControllerBackedProtocol?
    ) {
        guard let giftView = GiftPrepareShareViewFactory.createView(
            giftId: id,
            chainAsset: chainAsset,
            style: .share
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            giftView.controller,
            animated: true
        )
    }
}
