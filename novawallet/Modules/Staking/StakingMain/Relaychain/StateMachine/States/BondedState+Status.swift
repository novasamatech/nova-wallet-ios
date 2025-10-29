import Foundation

extension BondedState {
    var status: NominationViewStatus {
        .inactive
    }

    func createStatusPresentableViewModel(locale: Locale?) -> AlertPresentableViewModel? {
        switch status {
        case .inactive:
            return createInactiveStatus(locale: locale)
        case .active, .waiting, .undefined:
            return nil
        }
    }

    private func createInactiveStatus(locale: Locale?) -> AlertPresentableViewModel {
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusAlertInactiveTitle()
        let message: String

        message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingBondedInactive()

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }
}
