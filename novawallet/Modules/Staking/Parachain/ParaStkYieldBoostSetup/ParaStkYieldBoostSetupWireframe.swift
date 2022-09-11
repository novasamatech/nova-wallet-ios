import Foundation
import SoraFoundation

final class ParaStkYieldBoostSetupWireframe: ParaStkYieldBoostSetupWireframeProtocol {
    func showStartYieldBoostConfirmation(
        from _: ParaStkYieldBoostSetupViewProtocol?,
        model _: ParaStkYieldBoostConfirmModel
    ) {
        // TODO: Implement transition to confirmation screen
    }

    func showStopYieldBoostConfirmation(
        from _: ParaStkYieldBoostSetupViewProtocol?,
        collatorId _: AccountId,
        collatorIdentity _: AccountIdentity?
    ) {
        // TODO: Implement transition to confirmation screen
    }

    func showDelegationSelection(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let infoVew = ModalPickerFactory.createCollatorsPickingList(
            viewModels,
            actionViewModel: nil,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
