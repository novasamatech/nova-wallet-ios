import Foundation
import Foundation_iOS

typealias CollatorStakingTargetPicker = ModalPickerViewController<
    AccountDetailsGenericSelectionCell<AccountDetailsBalanceDecorator>,
    SelectableViewModel<AccountDetailsSelectionViewModel>
>

struct CollatorStakingTargetPickerContent {
    let title: LocalizableResource<String>?
    let viewModels: [AccountDetailsPickerViewModel]
    let action: LocalizableResource<IconWithTitleViewModel>?
    let selectedIndex: Int
}

protocol CollatorStakingDelegationSelectable {
    func showDelegationSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )

    func showUndelegationSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )
}

extension CollatorStakingDelegationSelectable {
    func showDelegationSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        let actionViewModel: LocalizableResource<IconWithTitleViewModel> = LocalizableResource { locale in
            let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonNewCollator()
            let icon = R.image.iconBlueAdd()

            return IconWithTitleViewModel(icon: icon, title: title)
        }

        showTargetSelection(
            from: view,
            content: CollatorStakingTargetPickerContent(
                title: nil,
                viewModels: viewModels,
                action: actionViewModel,
                selectedIndex: selectedIndex
            ),
            delegate: delegate,
            context: context
        )
    }

    func showUndelegationSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        showTargetSelection(
            from: view,
            content: CollatorStakingTargetPickerContent(
                title: nil,
                viewModels: viewModels,
                action: nil,
                selectedIndex: selectedIndex
            ),
            delegate: delegate,
            context: context
        )
    }

    @discardableResult
    func showTargetSelection(
        from view: ControllerBackedProtocol?,
        content: CollatorStakingTargetPickerContent,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) -> CollatorStakingTargetPicker? {
        guard let picker = ModalPickerFactory.createCollatorsPickingList(
            content.viewModels,
            actionViewModel: content.action,
            selectedIndex: content.selectedIndex,
            delegate: delegate,
            context: context,
            title: content.title
        ) else {
            return nil
        }

        view?.controller.present(picker, animated: true, completion: nil)

        return picker
    }
}
