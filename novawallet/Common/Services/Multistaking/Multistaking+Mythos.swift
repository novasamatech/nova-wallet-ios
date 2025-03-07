import Foundation
import SubstrateSdk

extension Multistaking {
    struct MythosStakingState {
        let sessionCollators: Set<AccountId>
        let userStake: MythosStakingPallet.UserStake?
        let freezes: BalancesPallet.Freezes?

        func applying(change: MythosStakingStateChange) -> MythosStakingState {
            let newStake = change.userStake.valueWhenDefined(else: userStake)
            let newFreezes = change.freezes.valueWhenDefined(else: freezes)
            let newSessionCollators = change.sessionCollators.valueWhenDefined(else: sessionCollators)

            return .init(
                sessionCollators: newSessionCollators,
                userStake: newStake,
                freezes: newFreezes
            )
        }

        var hasActiveStaking: Bool {
            guard let userStake, userStake.stake > 0 else {
                return false
            }

            return userStake.candidates.contains { sessionCollators.contains($0.wrappedValue) }
        }
    }

    struct MythosStakingStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case userStake
            case freezes
            case sessionCollators
        }

        let userStake: UncertainStorage<MythosStakingPallet.UserStake?>
        let freezes: UncertainStorage<BalancesPallet.Freezes?>
        let sessionCollators: UncertainStorage<Set<AccountId>>
        let blockHash: Data?

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson: JSON,
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

            sessionCollators = try UncertainStorage<[BytesCodable]>(
                values: values,
                mappingKey: Key.sessionCollators.rawValue,
                context: context
            ).map { value in
                let collators = value.map(\.wrappedValue)
                return Set(collators)
            }

            blockHash = try blockHashJson.map(to: Data?.self, with: context)
        }
    }
}
