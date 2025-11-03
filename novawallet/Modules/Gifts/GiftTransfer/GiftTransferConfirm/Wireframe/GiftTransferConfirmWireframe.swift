import Foundation
import UIKit

class GiftTransferConfirmWireframe: GiftTransferConfirmWireframeProtocol {
    func showGiftShare(
        from view: ControllerBackedProtocol?,
        giftId: GiftModel.Id,
        chainAsset: ChainAsset
    ) {
        guard let giftPrepareView = GiftPrepareShareViewFactory.createView(
            giftId: giftId,
            chainAsset: chainAsset,
            style: .prepareShare
        ) else { return }

        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .fade

        view?.controller.navigationController?.view.layer.add(
            transition,
            forKey: nil
        )
        view?.controller.navigationController?.setViewControllers(
            [giftPrepareView.controller],
            animated: false
        )
    }
}
