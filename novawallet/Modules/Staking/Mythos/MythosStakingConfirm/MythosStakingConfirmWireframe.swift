import Foundation

final class MythosStakingConfirmWireframe: MythosStakingConfirmWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func complete(on view: CollatorStakingConfirmViewProtocol?, locale: Locale) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        if viewControllers.contains(where: { $0 is StartStakingInfoViewProtocol }) {
            presentExtrinsicSubmission(
                from: view,
                completionAction: .popBaseAndDismiss,
                locale: locale
            )
        } else {
            presentExtrinsicSubmission(
                from: view,
                completionAction: .dismiss,
                locale: locale
            )
        }
    }
}
