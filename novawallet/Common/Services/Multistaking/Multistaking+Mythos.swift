import Foundation
import SubstrateSdk

extension Multistaking {
    struct MythosStakingState {
        let userStake: MythosStakingPallet.UserStake?
        let freezes: BalancesPallet.Freezes?
        let candidatesDetails: MythosDelegatorStakeDistribution?
        let session: SessionIndex

        func applying(change: MythosStakingStateChange) -> MythosStakingState {
            let newStake = change.userStake.valueWhenDefined(else: userStake)
            let newFreezes = change.freezes.valueWhenDefined(else: freezes)
            let newSession = change.session.valueWhenDefined(else: session)

            let newCandidatesDetails = !change.userStake.isDefined ? candidatesDetails : nil

            return .init(
                userStake: newStake,
                freezes: newFreezes,
                candidatesDetails: newCandidatesDetails,
                session: newSession
            )
        }

        func applying(candidatesDetails: MythosDelegatorStakeDistribution?) -> MythosStakingState {
            .init(
                userStake: userStake,
                freezes: freezes,
                candidatesDetails: candidatesDetails,
                session: session
            )
        }

        var isStartedInCurrentSession: Bool {
            guard let userStake else {
                return false
            }

            return userStake.candidates.allSatisfy { candidate in
                candidatesDetails?[candidate.wrappedValue]?.session == session
            }
        }
    }

    struct MythosStakingStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case userStake
            case freezes
            case session
        }

        let userStake: UncertainStorage<MythosStakingPallet.UserStake?>
        let freezes: UncertainStorage<BalancesPallet.Freezes?>
        let session: UncertainStorage<SessionIndex>
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

            session = try UncertainStorage<StringScaleMapper<SessionIndex>>(
                values: values,
                mappingKey: Key.session.rawValue,
                context: context
            ).map(\.value)

            blockHash = try blockHashJson.map(to: Data?.self, with: context)
        }
    }
}
