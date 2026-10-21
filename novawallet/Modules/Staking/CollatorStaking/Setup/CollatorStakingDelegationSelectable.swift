import Foundation
import Foundation_iOS

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

    func showTargetSelection(
        from view: ControllerBackedProtocol?,
        content: CollatorStakingTargetPickerContent,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let infoVew = ModalPickerFactory.createCollatorsPickingList(
            content.viewModels,
            actionViewModel: content.action,
            selectedIndex: content.selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        if let title = content.title, let picker = infoVew as? ModalPickerViewController<
            AccountDetailsGenericSelectionCell<AccountDetailsBalanceDecorator>,
            SelectableViewModel<AccountDetailsSelectionViewModel>
        > {
            picker.localizedTitle = title
        }

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
