import Foundation

final class ParaStkUnstakeWireframe: ParaStkUnstakeWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }

    func showUnstakingCollatorSelection(
        from view: ParaStkUnstakeViewProtocol?,
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

    func showUnstakingConfirm(
        from view: ParaStkUnstakeViewProtocol?,
        collator: DisplayAddress,
        callWrapper: UnstakeCallWrapper
    ) {
        guard let confirmView = ParaStkUnstakeConfirmViewFactory.createView(
            for: state,
            callWrapper: callWrapper,
            collator: collator
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
