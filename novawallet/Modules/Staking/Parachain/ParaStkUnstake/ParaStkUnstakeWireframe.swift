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
        from _: ParaStkUnstakeViewProtocol?,
        collator _: DisplayAddress,
        callWrapper _: UnstakeCallWrapper
    ) {
        // TODO: Add confirmation screen logic when implemented
    }
}
