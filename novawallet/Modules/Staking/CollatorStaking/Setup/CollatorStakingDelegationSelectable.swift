import Foundation
import Foundation_iOS

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
        showDelegationSelection(
            from: view,
            viewModels: viewModels,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context,
            statics: .collator
        )
    }

    func showUndelegationSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        showUndelegationSelection(
            from: view,
            viewModels: viewModels,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context,
            statics: .collator
        )
    }

    func showDelegationSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?,
        statics: CollatorStakingDelegateStatics
    ) {
        let actionViewModel: LocalizableResource<IconWithTitleViewModel> = LocalizableResource { locale in
            let title = statics.newDelegateTitle.value(for: locale)
            let icon = R.image.iconBlueAdd()

            return IconWithTitleViewModel(icon: icon, title: title)
        }

        guard let infoVew = ModalPickerFactory.createCollatorsPickingList(
            viewModels,
            actionViewModel: actionViewModel,
            title: statics.delegateTitle,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(infoVew, animated: true, completion: nil)
    }

    func showUndelegationSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?,
        statics: CollatorStakingDelegateStatics
    ) {
        guard let infoVew = ModalPickerFactory.createCollatorsPickingList(
            viewModels,
            actionViewModel: nil,
            title: statics.delegateTitle,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
