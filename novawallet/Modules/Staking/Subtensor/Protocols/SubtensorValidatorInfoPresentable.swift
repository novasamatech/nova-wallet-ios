import UIKit

protocol SubtensorValidatorInfoPresentable {
    var state: SubtensorStakingSharedStateProtocol { get }

    func showValidatorInfo(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        detail: SubtensorValidatorDetail?
    )
}

extension SubtensorValidatorInfoPresentable {
    func showValidatorInfo(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        detail: SubtensorValidatorDetail?
    ) {
        guard
            let view,
            let infoView = SubtensorValidatorInfoViewFactory.createView(
                for: state,
                target: target,
                hotkey: hotkey,
                detail: detail
            ) else {
            return
        }

        if let navigationController = view.controller.navigationController {
            navigationController.pushViewController(infoView.controller, animated: true)
        } else {
            let navigationController = NovaNavigationController(rootViewController: infoView.controller)

            view.controller.presentWithCardLayout(navigationController, animated: true)
        }
    }
}
