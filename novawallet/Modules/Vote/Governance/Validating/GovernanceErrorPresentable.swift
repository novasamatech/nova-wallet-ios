import Foundation

protocol GovernanceErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughTokensToVote(
        from view: ControllerBackedProtocol,
        available: String,
        locale: Locale?
    )

    func presentReferendumCompleted(
        from view: ControllerBackedProtocol,
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
}

extension GovernanceErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughTokensToVote(
        from view: ControllerBackedProtocol,
        available: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.commonAmountTooBig(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.govNotEnoughVoteTokens(available, preferredLanguages: locale?.rLanguages)

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentReferendumCompleted(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.govReferendumCompletedTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.govReferendumCompletedMessage(preferredLanguages: locale?.rLanguages)

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
}
