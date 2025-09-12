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
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonAmountTooBig()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govNotEnoughVoteTokens(available)

        if let maxAction = maxAction {
            let cancelTitle = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonCancel()

            let maxTitle = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swipeGovAmountAlertUseMax()

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
            let close = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonClose()

            present(message: message, title: title, closeAction: close, from: view)
        }
    }

    func presentReferendumCompleted(
        from view: ControllerBackedProtocol,
        referendumId: ReferendumIdLocal?,
        locale: Locale?
    ) {
        let title = if let referendumId {
            R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.govReferendumCompletedTitleWithIndex(
                Int(referendumId)
            )
        } else {
            R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.govReferendumCompletedTitle()
        }

        let message = if let referendumId {
            R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.govReferendumCompletedMessageWithIndex(
                Int(referendumId)
            )
        } else {
            R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.govReferendumCompletedMessage()
        }

        let close = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentAlreadyDelegatingVotes(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govAlreadyDelegatingVotesTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govAlreadyDelegatingVotesMessage()

        let close = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentVotesMaximumNumberReached(
        from view: ControllerBackedProtocol,
        allowed: String,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govMaxVotesReachedTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govMaxVotesReachedMessage(allowed)

        let close = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentSelfDelegating(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govAddDelegateSelfErrorTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govAddDelegateSelfErrorMessage()

        let close = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentAlreadyVoting(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.govAddDelegateVotingErrorTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.govAddDelegateVotingErrorMessage()

        let close = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentAlreadyRevokedDelegation(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.govRevokeDelegateMissingErrorTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.govRevokeDelegateMissingErrorMessage()

        let close = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentConvictionUpdateRequired(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let languages = locale.rLanguages
        let actions = [
            AlertPresentableAction(
                title: R.string(preferredLanguages: languages).localizable.commonCancel(),
                style: .destructive,
                handler: {}
            ),
            AlertPresentableAction(
                title: R.string(preferredLanguages: languages).localizable.commonContinue(),
                style: .normal,
                handler: action
            )
        ]
        let viewModel = AlertPresentableViewModel(
            title: R.string(preferredLanguages: languages).localizable.govVoteConvictionAlertTitle(),
            message: R.string(preferredLanguages: languages).localizable.govVoteConvictionAlertMessage(),
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
