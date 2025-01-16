import Foundation
import Foundation_iOS

final class ParaStkYieldBoostSetupWireframe: ParaStkYieldBoostSetupWireframeProtocol {
    let state: ParachainStakingSharedStateProtocol

    init(state: ParachainStakingSharedStateProtocol) {
        self.state = state
    }

    func showStartYieldBoostConfirmation(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        model: ParaStkYieldBoostConfirmModel
    ) {
        guard let scheduleConfirmView = ParaStkYieldBoostStartViewFactory.createView(
            with: state,
            confirmModel: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(scheduleConfirmView.controller, animated: true)
    }

    func showStopYieldBoostConfirmation(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        collatorId: AccountId,
        collatorIdentity: AccountIdentity?
    ) {
        guard let cancelConfirmView = ParaStkYieldBoostStopViewFactory.createView(
            with: state,
            collatorId: collatorId,
            collatorIdentity: collatorIdentity
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(cancelConfirmView.controller, animated: true)
    }

    func showDelegationSelection(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let pickerVew = ModalPickerFactory.createYieldBoostCollatorsSelectionList(
            viewModels,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(pickerVew, animated: true, completion: nil)
    }
}
