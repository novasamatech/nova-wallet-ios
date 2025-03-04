import Foundation

protocol CollatorStkManageCollatorsPresentable {
    func showManageCollators(
        from view: CollatorStkYourCollatorsViewProtocol?,
        options: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )
}

extension CollatorStkManageCollatorsPresentable {
    func showManageCollators(
        from view: CollatorStkYourCollatorsViewProtocol?,
        options: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let picker = ModalPickerFactory.createStakingManageSource(
            options: options,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }
}
