import Foundation

final class GiftsOnboardingWireframe: GiftsOnboardingWireframeProtocol {
    private let stateObservable: AssetListModelObservable
    private let transferCompletion: TransferCompletionClosure
    private let buyTokensClosure: BuyTokensClosure

    init(
        stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) {
        self.stateObservable = stateObservable
        self.transferCompletion = transferCompletion
        self.buyTokensClosure = buyTokensClosure
    }

    func showCreateGift(from view: GiftsOnboardingViewProtocol?) {
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
}
