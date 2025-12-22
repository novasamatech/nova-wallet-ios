import Foundation
import NovaCrypto
import BigInt

extension ValidatorState {
    var status: ValidationViewStatus {
        guard let eraStakers = commonData.eraStakersInfo else {
            return .undefined
        }

        do {
            guard ledgerInfo.active > 0 else {
                return .inactive(era: eraStakers.activeEra)
            }

            let accountId = try stashItem.stash.toAccountId()

            if eraStakers.validators
                .first(where: { $0.accountId == accountId }) != nil {
                return .active(era: eraStakers.activeEra)
            }
            return .inactive(era: eraStakers.activeEra)

        } catch {
            return .undefined
        }
    }

    func createStatusPresentableViewModel(
        for locale: Locale?
    ) -> AlertPresentableViewModel? {
        switch status {
        case .active:
            return createActiveStatus(for: locale)
        case .inactive:
            return createInactiveStatus(for: locale)
        case .undefined:
            return createUndefinedStatus(for: locale)
        }
    }

    private func createActiveStatus(
        for locale: Locale?
    ) -> AlertPresentableViewModel? {
        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusAlertActiveTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusAlertActiveMessage()

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createInactiveStatus(
        for locale: Locale?
    ) -> AlertPresentableViewModel? {
        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusAlertInactiveTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusAlertNoValidators()

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createUndefinedStatus(
        for _: Locale?
    ) -> AlertPresentableViewModel? {
        nil
    }
}
