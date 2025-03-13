import Foundation

final class PayCardWireframe: PayCardWireframeProtocol {
    func showSend(
        from view: ControllerBackedProtocol?,
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

    func showCardFundingState(
        from view: ControllerBackedProtocol?,
        mode: PayCardSheetMode,
        timerMediator: CountdownTimerMediator,
        totalTime: TimeInterval,
        locale: Locale?
    ) {
        guard let sheetView = PayCardSheetViewFactory.createCardFundingSheet(
            for: mode,
            timerMediator: timerMediator,
            totalTime: totalTime,
            locale: locale
        ) else {
            return
        }

        view?.controller.present(sheetView.controller, animated: true)
    }

    func closeCardOpenSheet(
        from view: ControllerBackedProtocol?,
        completion: (() -> Void)?
    ) {
        view?.controller.dismiss(
            animated: true,
            completion: completion
        )
    }
}
