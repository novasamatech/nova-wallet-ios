import Foundation
import UIKit
import UIKit_iOS

class StartStakingInfoWireframe: StartStakingInfoWireframeProtocol {
    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let accountManagementView = AccountManagementViewFactory.createView(for: wallet.identifier) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountManagementView.controller, animated: true)
    }

    func showSetupAmount(from _: ControllerBackedProtocol?) {
        fatalError("Must be overriden by subsclass")
    }

    func complete(from view: ControllerBackedProtocol?) {
        MainTransitionHelper.dismissAndPopBack(from: view)
    }

    func presentCriticalNoticeSheet(
        from view: StartStakingInfoViewProtocol?,
        title: String,
        body: String,
        onCancel: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        guard let sheetView = StartStakingCriticalNoticeSheetViewFactory.createView(
            title: title,
            body: body,
            onCancel: onCancel,
            onContinue: onContinue
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.nova
        )
        sheetView.controller.modalTransitioningFactory = factory
        sheetView.controller.modalPresentationStyle = .custom

        view?.controller.present(sheetView.controller, animated: true, completion: nil)
    }
}
