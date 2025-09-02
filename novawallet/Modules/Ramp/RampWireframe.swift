import Foundation
import UIKit

final class RampWireframe {
    private weak var delegate: RampDelegate?

    init(delegate: RampDelegate?) {
        self.delegate = delegate
    }
}

extension RampWireframe: RampWireframeProtocol {
    func complete(
        from _: RampViewProtocol?,
        with action: RampActionType,
        for chainAsset: ChainAsset
    ) {
        delegate?.rampDidComplete(
            action: action,
            chainAsset: chainAsset
        )
    }

    func showSend(
        from view: (any ControllerBackedProtocol)?,
        with transferModel: PayCardTopupModel
    ) {
        guard let sendTransferView = TransferSetupViewFactory.createOffRampView(
            from: transferModel.chainAsset,
            recepient: DisplayAddress(address: transferModel.recipientAddress, username: ""),
            amount: transferModel.amount
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: sendTransferView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }
}

protocol RampDelegate: AnyObject {
    func rampDidComplete(
        action: RampActionType,
        chainAsset: ChainAsset
    )
}
