import Foundation
import UIKit

class GiftTransferSetupWireframe {
    let assetListObservable: AssetListModelObservable
    let buyTokensClosure: BuyTokensClosure?
    let transferCompletion: TransferCompletionClosure?

    init(
        assetListStateObservable: AssetListModelObservable,
        buyTokensClosure: BuyTokensClosure?,
        transferCompletion: TransferCompletionClosure?
    ) {
        assetListObservable = assetListStateObservable
        self.buyTokensClosure = buyTokensClosure
        self.transferCompletion = transferCompletion
    }
}

extension GiftTransferSetupWireframe: GiftTransferSetupWireframeProtocol {
    func showConfirmation(
        from view: (any GiftTransferSetupViewProtocol)?,
        chainAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>
    ) {
        guard let confirmView = GiftTransferConfirmViewFactory.createView(
            from: chainAsset,
            amount: sendingAmount,
            transferCompletion: transferCompletion
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

    func popTopControllers(
        from view: ControllerBackedProtocol?,
        completion: @escaping () -> Void
    ) {
        guard let controller = view?.controller else { return }

        if let presentedViewController = controller.presentedViewController {
            // In case we have many providers, selection screen is presented modally
            presentedViewController.dismiss(
                animated: true,
                completion: completion
            )
        } else {
            // In case we have single provider, ramp screen is pushed on navigation stack
            CATransaction.begin()
            CATransaction.setCompletionBlock { completion() }

            controller.navigationController?.popToViewController(
                controller,
                animated: true
            )

            CATransaction.commit()
        }
    }
}
