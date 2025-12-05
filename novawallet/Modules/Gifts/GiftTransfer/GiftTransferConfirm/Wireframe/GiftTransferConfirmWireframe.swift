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
        giftId: GiftModel.Id,
        chainAsset: ChainAsset
    ) {
        guard let view, let giftPrepareView = GiftPrepareShareViewFactory.createView(
            giftId: giftId,
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
