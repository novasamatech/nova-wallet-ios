import Foundation
import SubstrateSdk

extension Multistaking {
    struct RelaychainAccountsChange: BatchStorageSubscriptionResult {
        // swiftlint:disable:next nesting
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
            stash = try UncertainStorage<StakingLedger?>(
                values: values,
                localKey: Key.stash.rawValue,
                context: context
            ).map { $0?.stash }

            controller = try UncertainStorage<BytesCodable?>(
                values: values,
                localKey: Key.controller.rawValue,
                context: context
            ).map { $0?.wrappedValue }
        }
    }

    struct RelaychainStateChange: BatchStorageSubscriptionResult {
        // swiftlint:disable:next nesting
        enum Key: String {
            case era
            case ledger
            case nomination
        }

        let era: UncertainStorage<ActiveEraInfo>
        let ledger: UncertainStorage<StakingLedger?>
        let nomination: UncertainStorage<Nomination?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            ledger = try UncertainStorage(
                values: values,
                localKey: Key.ledger.rawValue,
                context: context
            )

            nomination = try UncertainStorage(
                values: values,
                localKey: Key.nomination.rawValue,
                context: context
            )

            era = try UncertainStorage(
                values: values,
                localKey: Key.era.rawValue,
                context: context
            )
        }
    }
}
