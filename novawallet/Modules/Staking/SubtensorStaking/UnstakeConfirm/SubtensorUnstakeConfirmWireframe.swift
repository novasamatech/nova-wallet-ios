import Foundation
import UIKit

final class SubtensorUnstakeConfirmWireframe: SubtensorUnstakeConfirmWireframeProtocol,
    ModalAlertPresenting,
    ExtrinsicSubmissionPresenting {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        locale: Locale
    ) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        // Pop back to the multistaking dashboard (one level above the TAO
        // dashboard) so the user doesn't land on the SubtensorStaking
        // empty-state when they just unstaked their whole position.
        if let multistakingVC = viewControllers.first(where: { $0 is StakingDashboardViewController }) {
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .popToViewController(multistakingVC),
                locale: locale
            )
        } else if let dashboardVC = viewControllers.first(where: { $0 is SubtensorStakingViewController }) {
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
