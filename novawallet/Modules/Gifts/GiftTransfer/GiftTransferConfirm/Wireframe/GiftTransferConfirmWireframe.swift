import Foundation
import UIKit_iOS
import UIKit

class GiftTransferConfirmWireframe: GiftTransferConfirmWireframeProtocol {
    private let animator: ViewAnimatorProtocol = TransitionAnimator(
        type: .fade,
        duration: 0.3,
        curve: .easeInEaseOut
    )

    func showGiftShare(
        from view: ControllerBackedProtocol?,
        giftAccountId: AccountId,
        giftId: GiftModel.Id,
        chainAsset: ChainAsset
    ) {
        guard let view, let giftPrepareView = GiftPrepareShareViewFactory.createView(
            giftId: giftId,
            giftAccountId: giftAccountId,
            chainAsset: chainAsset,
            style: .prepareShare
        ) else { return }

        animator.animate(
            view: view.controller.view
        ) { _ in
            view.controller.navigationController?.setViewControllers(
                [giftPrepareView.controller],
                animated: false
            )
        }
    }
}
