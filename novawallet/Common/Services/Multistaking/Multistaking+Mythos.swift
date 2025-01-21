import Foundation
import SubstrateSdk

extension Multistaking {
    struct MythosStakingState {
        let userStake: MythosStakingPallet.UserStake?
        let freezes: BalancesPallet.Freezes?

        func applying(change: MythosStakingStateChange) -> MythosStakingState {
            let newStake = change.userStake.valueWhenDefined(else: userStake)
            let newFreezes = change.freezes.valueWhenDefined(else: freezes)

            return .init(userStake: newStake, freezes: newFreezes)
        }
    }

    struct MythosStakingStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case userStake
            case freezes
        }

        let userStake: UncertainStorage<MythosStakingPallet.UserStake?>
        let freezes: UncertainStorage<BalancesPallet.Freezes?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            userStake = try UncertainStorage(
                values: values,
                mappingKey: Key.userStake.rawValue,
                context: context
            )

            freezes = try UncertainStorage(
                values: values,
                mappingKey: Key.freezes.rawValue,
                context: context
            )
        }
    }
}
