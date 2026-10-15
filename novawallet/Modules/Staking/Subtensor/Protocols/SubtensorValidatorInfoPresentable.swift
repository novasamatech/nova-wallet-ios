import UIKit

protocol SubtensorValidatorInfoPresentable {
    var state: SubtensorStakingSharedStateProtocol { get }
}

extension SubtensorValidatorInfoPresentable {
    func showValidatorInfo(
        from view: ControllerBackedProtocol?,
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        detail: SubtensorValidatorDirectoryItem?,
        needsChainDetail: Bool = false
    ) {
        guard
            let view,
            let infoView = SubtensorValidatorInfoViewFactory.createView(
                for: state,
                target: target,
                hotkey: hotkey,
                detail: detail,
                needsChainDetail: needsChainDetail
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
