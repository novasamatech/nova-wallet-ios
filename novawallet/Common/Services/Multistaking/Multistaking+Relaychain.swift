import Foundation
import SubstrateSdk

extension Multistaking {
    struct RelaychainAccountsChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case controller
            case stash
        }

        let controller: UncertainStorage<AccountId?>
        let stash: UncertainStorage<AccountId?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            stash = try UncertainStorage<Staking.Ledger?>(
                values: values,
                mappingKey: Key.stash.rawValue,
                context: context
            ).map { $0?.stash }

            controller = try UncertainStorage<BytesCodable?>(
                values: values,
                mappingKey: Key.controller.rawValue,
                context: context
            ).map { $0?.wrappedValue }
        }
    }

    struct RelaychainState {
        let era: Staking.ActiveEraInfo
        let ledger: Staking.Ledger?
        let nomination: Staking.Nomination?
        let validatorPrefs: Staking.ValidatorPrefs?

        func applying(change: RelaychainStateChange) -> RelaychainState {
            let newEra: Staking.ActiveEraInfo = change.era.valueWhenDefined(else: era)
            let newLedger = change.ledger.valueWhenDefined(else: ledger)
            let newNomination = change.nomination.valueWhenDefined(else: nomination)
            let newValidatorPrefs = change.validatorPrefs.valueWhenDefined(else: validatorPrefs)

            return .init(
                era: newEra,
                ledger: newLedger,
                nomination: newNomination,
                validatorPrefs: newValidatorPrefs
            )
        }
    }

    struct RelaychainStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case era
            case ledger
            case nomination
            case validatorPrefs
        }

        let era: UncertainStorage<Staking.ActiveEraInfo>
        let ledger: UncertainStorage<Staking.Ledger?>
        let nomination: UncertainStorage<Staking.Nomination?>
        let validatorPrefs: UncertainStorage<Staking.ValidatorPrefs?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            ledger = try UncertainStorage(
                values: values,
                mappingKey: Key.ledger.rawValue,
                context: context
            )

            nomination = try UncertainStorage(
                values: values,
                mappingKey: Key.nomination.rawValue,
                context: context
            )

            validatorPrefs = try UncertainStorage(
                values: values,
                mappingKey: Key.validatorPrefs.rawValue,
                context: context
            )

            era = try UncertainStorage(
                values: values,
                mappingKey: Key.era.rawValue,
                context: context
            )
        }
    }
}
