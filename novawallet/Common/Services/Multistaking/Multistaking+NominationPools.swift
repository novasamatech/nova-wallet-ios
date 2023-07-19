import Foundation

extension Multistaking {
    struct NominationPoolStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case ledger
            case bonded
        }

        let ledger: UncertainStorage<StakingLedger?>
        let bondedPool: UncertainStorage<NominationPools.BondedPool?>

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

            bondedPool = try UncertainStorage(
                values: values,
                localKey: Key.bonded.rawValue,
                context: context
            )
        }
    }
}
