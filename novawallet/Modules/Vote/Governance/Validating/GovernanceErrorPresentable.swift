import Foundation

protocol GovernanceErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughTokensToVote(
        from view: ControllerBackedProtocol,
        available: String,
        maxAction: (() -> Void)?,
        locale: Locale?
    )

    func presentReferendumCompleted(
        from view: ControllerBackedProtocol,
        referendumId: ReferendumIdLocal?,
        locale: Locale?
    )

    func presentAlreadyDelegatingVotes(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentVotesMaximumNumberReached(
        from view: ControllerBackedProtocol,
        allowed: String,
        locale: Locale?
    )

    func presentSelfDelegating(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentAlreadyVoting(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentAlreadyRevokedDelegation(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentConvictionUpdateRequired(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )
}

extension GovernanceErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughTokensToVote(
        from view: ControllerBackedProtocol,
        available: String,
        maxAction: (() -> Void)?,
        locale: Locale?
    ) {
        let title = R.string.localizable.commonAmountTooBig(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.govNotEnoughVoteTokens(available, preferredLanguages: locale?.rLanguages)

        if let maxAction = maxAction {
            let cancelTitle = R.string.localizable.commonCancel(
                preferredLanguages: locale?.rLanguages
            )

            let maxTitle = R.string.localizable.swipeGovAmountAlertUseMax(
                preferredLanguages: locale?.rLanguages
            )

            present(
                viewModel: .init(
                    title: title,
                    message: message,
                    actions: [
                        .init(title: cancelTitle),
                        .init(title: maxTitle, handler: maxAction)
                    ],
                    closeAction: nil
                ),
                style: .alert,
                from: view
            )
        } else {
            let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

            present(message: message, title: title, closeAction: close, from: view)
        }
    }

    func presentReferendumCompleted(
        from view: ControllerBackedProtocol,
        referendumId: ReferendumIdLocal?,
        locale: Locale?
    ) {
        let title = if let referendumId {
            R.string.localizable.govReferendumCompletedTitleWithIndex(
                Int(referendumId),
                preferredLanguages: locale?.rLanguages
            )
        } else {
            R.string.localizable.govReferendumCompletedTitle(
                preferredLanguages: locale?.rLanguages
            )
        }

        let message = if let referendumId {
            R.string.localizable.govReferendumCompletedMessageWithIndex(
                Int(referendumId),
                preferredLanguages: locale?.rLanguages
            )
        } else {
            R.string.localizable.govReferendumCompletedMessage(
                preferredLanguages: locale?.rLanguages
            )
        }

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentAlreadyDelegatingVotes(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.govAlreadyDelegatingVotesTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.govAlreadyDelegatingVotesMessage(preferredLanguages: locale?.rLanguages)

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentVotesMaximumNumberReached(
        from view: ControllerBackedProtocol,
        allowed: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.govMaxVotesReachedTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.govMaxVotesReachedMessage(allowed, preferredLanguages: locale?.rLanguages)

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentSelfDelegating(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.govAddDelegateSelfErrorTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.govAddDelegateSelfErrorMessage(
            preferredLanguages: locale?.rLanguages
        )

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentAlreadyVoting(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.govAddDelegateVotingErrorTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.govAddDelegateVotingErrorMessage(preferredLanguages: locale?.rLanguages)

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentAlreadyRevokedDelegation(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.govRevokeDelegateMissingErrorTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.govRevokeDelegateMissingErrorMessage(preferredLanguages: locale?.rLanguages)

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentConvictionUpdateRequired(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let languages = locale?.rLanguages
        let actions = [
            AlertPresentableAction(
                title: R.string.localizable.commonCancel(preferredLanguages: languages),
                style: .destructive,
                handler: {}
            ),
            AlertPresentableAction(
                title: R.string.localizable.commonContinue(preferredLanguages: languages),
                style: .normal,
                handler: action
            )
        ]
        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.govVoteConvictionAlertTitle(preferredLanguages: languages),
            message: R.string.localizable.govVoteConvictionAlertMessage(preferredLanguages: languages),
            actions: actions,
            closeAction: nil
        )

        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }
}
