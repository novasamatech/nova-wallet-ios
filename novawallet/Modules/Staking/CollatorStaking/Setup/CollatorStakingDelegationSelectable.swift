import Foundation
import SoraFoundation

protocol CollatorStakingDelegationSelectable {
    func showDelegationSelection(
        from view: CollatorStakingSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )
}

extension CollatorStakingDelegationSelectable {
    func showDelegationSelection(
        from view: CollatorStakingSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        let actionViewModel: LocalizableResource<IconWithTitleViewModel> = LocalizableResource { locale in
            let title = R.string.localizable.commonNewCollator(preferredLanguages: locale.rLanguages)
            let icon = R.image.iconBlueAdd()

            return IconWithTitleViewModel(icon: icon, title: title)
        }

        guard let infoVew = ModalPickerFactory.createCollatorsPickingList(
            viewModels,
            actionViewModel: actionViewModel,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
