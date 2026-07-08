import Foundation
import UIKit

final class SubtensorStakeConfirmWireframe: SubtensorStakeConfirmWireframeProtocol,
    ModalAlertPresenting,
    ExtrinsicSubmissionPresenting {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        locale: Locale
    ) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        if viewControllers.contains(where: { $0 is StartStakingInfoViewProtocol }) {
            // Reached confirm via the modal Start-Staking flow — Nova's
            // canonical "pop the modal nav to root and dismiss".
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .popBaseAndDismiss,
                locale: locale
            )
            return
        }

        // Reached confirm via the TAO Staking dashboard's Stake more flow:
        // dashboard → type select → setup → confirm, all pushed in the same
        // (non-modal) nav stack. The default `.dismiss` action assumes a
        // modal presentation and silently no-ops here, leaving the user on
        // the confirm screen with the action button restored — which made
        // them tap Confirm a second time and fire two extrinsics. Pop back
        // to the TAO Staking dashboard so the success toast lands on a
        // sensible parent and there's no second-tap window.
        if let dashboardVC = viewControllers.first(where: { $0 is SubtensorStakingViewController }) {
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .popToViewController(dashboardVC),
                locale: locale
            )
        } else {
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .pop,
                locale: locale
            )
        }
    }
}
