import Foundation

final class ParaStkStakeSetupWireframe: ParaStkStakeSetupWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }

    func showConfirmation(
        from view: ParaStkStakeSetupViewProtocol?,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: ParachainStaking.Delegator?
    ) {
        guard let confirmView = ParaStkStakeConfirmViewFactory.createView(
            for: state,
            collator: collator,
            amount: amount,
            initialDelegator: initialDelegator
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

    func showCollatorSelection(
        from view: ParaStkStakeSetupViewProtocol?,
        delegate: ParaStkSelectCollatorsDelegate
    ) {
        guard let collatorsView = ParaStkSelectCollatorsViewFactory.createView(
            with: state,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(collatorsView.controller, animated: true)
    }

    func showDelegationSelection(
        from view: ParaStkStakeSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let infoVew = ModalPickerFactory.createCollatorsPickingList(
            viewModels,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
