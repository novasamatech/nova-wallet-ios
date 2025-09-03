import Foundation
import NovaCrypto
import BigInt

extension NominatorState {
    var status: NominationViewStatus {
        guard let eraStakers = commonData.eraStakersInfo else {
            return .undefined
        }

        do {
            guard ledgerInfo.active > 0 else {
                return .inactive
            }

            let accountId = try stashItem.stash.toAccountId()

            let allNominators = eraStakers.validators.map(\.exposure.others)
                .flatMap { (nominators) -> [Staking.IndividualExposure] in
                    if let maxNominatorsPerValidator = commonData.maxNominatorsPerValidator {
                        return Array(nominators.prefix(Int(maxNominatorsPerValidator)))
                    } else {
                        return nominators
                    }
                }
                .reduce(into: Set<Data>()) { $0.insert($1.who) }

            if allNominators.contains(accountId) {
                return .active
            }

            if nomination.submittedIn >= eraStakers.activeEra {
                return .waiting(eraCountdown: commonData.eraCountdown, nominationEra: nomination.submittedIn)
            }

            return .inactive

        } catch {
            return .undefined
        }
    }

    var allValidatorsWithoutReward: Bool {
        guard let eraStakers = commonData.eraStakersInfo else {
            return false
        }

        do {
            let accountId = try stashItem.stash.toAccountId()
            let nominatorPositions = eraStakers.validators.compactMap { validator in
                validator.exposure.others.firstIndex(where: { $0.who == accountId })
            }

            guard !nominatorPositions.isEmpty else {
                return false
            }

            if let maxNominatorsPerValidator = commonData.maxNominatorsPerValidator {
                return nominatorPositions.allSatisfy { $0 >= maxNominatorsPerValidator }
            } else {
                return true
            }

        } catch {
            return false
        }
    }

    var hasElectedValidators: Bool {
        guard let eraStakers = commonData.eraStakersInfo else {
            return true
        }

        do {
            let accountId = try stashItem.stash.toAccountId()

            return eraStakers.validators.contains { validator in
                validator.exposure.others.contains { $0.who == accountId }
            }
        } catch {
            return true
        }
    }

    func createStatusPresentableViewModel(
        locale: Locale?
    ) -> AlertPresentableViewModel? {
        switch status {
        case .active:
            return createActiveStatus(locale: locale)
        case .inactive:
            return createInactiveStatus(locale: locale)
        case .waiting:
            return createWaitingStatus(locale: locale)
        case .undefined:
            return createUndefinedStatus(locale: locale)
        }
    }

    private func createActiveStatus(locale: Locale?) -> AlertPresentableViewModel? {
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
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
        locale: Locale?
    ) -> AlertPresentableViewModel? {
        guard let minStake = commonData.minStake else {
            return nil
        }

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusAlertInactiveTitle()
        let message: String

        if ledgerInfo.active < minStake {
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingNominatorStatusAlertLowStake()
        } else if allValidatorsWithoutReward {
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingYourOversubscribedMessage()
        } else {
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingNominatorStatusAlertNoValidators()
        }

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createWaitingStatus(locale: Locale?) -> AlertPresentableViewModel? {
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusWaiting()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusAlertWaitingMessage()

        return AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createUndefinedStatus(locale _: Locale?) -> AlertPresentableViewModel? {
        nil
    }
}
