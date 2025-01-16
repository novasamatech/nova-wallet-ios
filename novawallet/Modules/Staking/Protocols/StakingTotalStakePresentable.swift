import Foundation
import Foundation_iOS

protocol StakingTotalStakePresentable: AnyObject {
    func showStakingAmounts(
        from view: ControllerBackedProtocol?,
        items: [LocalizableResource<StakingAmountViewModel>]
    )
}

extension StakingTotalStakePresentable {
    func showStakingAmounts(
        from view: ControllerBackedProtocol?,
        items: [LocalizableResource<StakingAmountViewModel>]
    ) {
        let maybeManageView = ModalPickerFactory.createPickerForList(
            items,
            delegate: nil,
            context: nil
        )
        guard let manageView = maybeManageView else { return }

        view?.controller.present(manageView, animated: true, completion: nil)
    }
}
