import Foundation

protocol SubtensorClaimErrorPresentable {
    func presentClaimPending(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentNothingToClaim(_ view: ControllerBackedProtocol, minimum: String, locale: Locale?)

    func presentClaimAmountChanged(_ view: ControllerBackedProtocol, locale: Locale?)
}

extension SubtensorClaimErrorPresentable where Self: AlertPresentable {
    func presentClaimPending(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        present(
            message: strings.stakingSubtensorClaimPendingMessage(),
            title: strings.stakingClaimRewards(),
            closeAction: strings.commonClose(),
            from: view
        )
    }

    func presentNothingToClaim(_ view: ControllerBackedProtocol, minimum: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        present(
            message: strings.stakingSubtensorClaimBelowMinimumMessageFormat(minimum),
            title: strings.stakingSubtensorClaimBelowMinimumTitle(),
            closeAction: strings.commonClose(),
            from: view
        )
    }

    func presentClaimAmountChanged(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        present(
            message: strings.stakingSubtensorClaimAmountChangedMessage(),
            title: strings.stakingClaimRewards(),
            closeAction: strings.commonClose(),
            from: view
        )
    }
}
