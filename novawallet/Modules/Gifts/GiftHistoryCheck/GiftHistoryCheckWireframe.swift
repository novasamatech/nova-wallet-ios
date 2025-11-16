import Foundation

final class GiftHistoryCheckWireframe: GiftHistoryCheckWireframeProtocol {
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

    func showOnboarding(from view: (any ControllerBackedProtocol)?) {
        guard let onboardingView = GiftsOnboardingViewFactory.createView(
            stateObservable: stateObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        ) else { return }

        view?.controller.navigationController?.setViewControllers(
            [onboardingView.controller],
            animated: false
        )
    }

    func showHistory(
        from view: (any ControllerBackedProtocol)?,
        gifts: [GiftModel]
    ) {
        print(view)
        print(gifts)
    }
}
