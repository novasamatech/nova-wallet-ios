import Foundation
import SoraFoundation

final class ParaStkYieldBoostSetupWireframe: ParaStkYieldBoostSetupWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
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
