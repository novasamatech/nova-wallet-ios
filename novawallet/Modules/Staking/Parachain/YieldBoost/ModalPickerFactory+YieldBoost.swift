import UIKit

extension ModalPickerFactory {
    static func createYieldBoostCollatorsSelectionList(
        _ items: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let controller: ModalPickerViewController<
            AccountDetailsGenericSelectionCell<AccountDetailsYieldBoostDecorator>,
            SelectableViewModel<AccountDetailsSelectionViewModel>
        >?

        controller = createGenericCollatorsPickingList(
            items,
            actionViewModel: nil,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        )

        return controller
    }
}
