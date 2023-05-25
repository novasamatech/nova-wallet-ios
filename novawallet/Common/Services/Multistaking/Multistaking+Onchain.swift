import Foundation
import SubstrateSdk

extension Multistaking {
    struct OnchainStateChange: BatchStorageSubscriptionResult {
        // swiftlint:disable:next nesting
        enum Key: String {
            case era
            case ledger
        }

        let era: UncertainStorage<ActiveEraInfo>
        let ledger: UncertainStorage<StakingLedger?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            if let ledgerValue = values.first(where: { Key(rawValue: $0.localKey) == .ledger }) {
                let value = try ledgerValue.value.map(to: StakingLedger?.self, with: context)
                ledger = .defined(value)
            } else {
                ledger = .undefined
            }

            if let eraValue = values.first(where: { Key(rawValue: $0.localKey) == .era }) {
                let value = try eraValue.value.map(to: ActiveEraInfo.self, with: context)
                era = .defined(value)
            } else {
                era = .undefined
            }
        }
    }
}
