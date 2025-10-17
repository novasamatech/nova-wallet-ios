import Foundation

protocol CrowdloanErrorPresentable: BaseErrorPresentable {
    func presentMinimalBalanceContributionError(
        _ value: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentCapReachedError(from view: ControllerBackedProtocol, locale: Locale?)

    func presentAmountExceedsCapError(_ amount: String, from view: ControllerBackedProtocol, locale: Locale?)

    func presentCrowdloanEnded(from view: ControllerBackedProtocol, locale: Locale?)

    func presentCrowdloanPrivateNotSupported(from view: ControllerBackedProtocol, locale: Locale?)

    func presentHaveNotAppliedBonusWarning(
        from view: ControllerBackedProtocol,
        locale: Locale?,
        action: @escaping (Bool) -> Void
    )
}

extension CrowdloanErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentMinimalBalanceContributionError(
        _ value: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanTooSmallContributionMessage(value)

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanTooSmallContributionTitle()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCapReachedError(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanCapReachedRaisedMessage()

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanCapReachedTitle()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentAmountExceedsCapError(_ amount: String, from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanCapReachedAmountMessage(
            amount
        )
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanCapReachedTitle()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCrowdloanEnded(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanEndedTitle()

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanEndedMessage()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCrowdloanPrivateNotSupported(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanPrivateCrowdloanMessage()

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanPrivateCrowdloanTitle()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentHaveNotAppliedBonusWarning(
        from view: ControllerBackedProtocol,
        locale: Locale?,
        action: @escaping (Bool) -> Void
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanHavenotAppliedBonusTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanHavenotAppliedBonusMessage()

        let applyTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanHavenotAppliedBonusApply()
        let applyAction = AlertPresentableAction(title: applyTitle) {
            action(true)
        }

        let skipTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonSkip()
        let skipAction = AlertPresentableAction(title: skipTitle, style: .destructive) {
            action(false)
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [skipAction, applyAction],
            closeAction: nil
        )

        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }
}
