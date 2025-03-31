import Foundation

import SoraFoundation

final class RampWireframe {
    private weak var delegate: RampDelegate?

    init(delegate: RampDelegate?) {
        self.delegate = delegate
    }
}

extension RampWireframe: RampWireframeProtocol {
    func complete(
        from view: RampViewProtocol?,
        with action: RampActionType
    ) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.delegate?.rampDidComplete(action: action)
            }
        }
    }

    func showSend(
        from view: (any ControllerBackedProtocol)?,
        with transferModel: PayCardTopupModel,
        transferCompletion: @escaping TransferCompletionClosure
    ) {
        guard let sendTransferView = TransferSetupViewFactory.createCardTopUpView(
            from: transferModel.chainAsset,
            recepient: DisplayAddress(address: transferModel.recipientAddress, username: ""),
            amount: transferModel.amount,
            transferCompletion: transferCompletion
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
    func rampDidComplete(action: RampActionType)
}
