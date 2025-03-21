import Foundation

typealias RampFlowManaging = OffRampFlowManaging & OnRampFlowManaging

protocol BaseRampFlowManaging: AnyObject {}

extension BaseRampFlowManaging where Self: RampDelegate {
    func startFlow(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        wireframe: (RampPresentable & AlertPresentable)?,
        locale: Locale
    ) {
        let title = R.string.localizable.commonAlertExternalLinkDisclaimerTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.commonAlertExternalLinkDisclaimerMessage(
            action.url.absoluteString,
            preferredLanguages: locale.rLanguages
        )

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let continueTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        let continueAction = AlertPresentableAction(title: continueTitle) {
            wireframe?.showRampAction(
                from: view,
                action: action,
                delegate: self
            )
        }

        wireframe?.present(
            viewModel: .init(
                title: title,
                message: message,
                actions: [continueAction],
                closeAction: closeTitle
            ),
            style: .alert,
            from: view
        )
    }
}
