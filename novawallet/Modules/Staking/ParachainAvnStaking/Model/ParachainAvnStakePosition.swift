import Foundation
import BigInt

/// User's open nominations on Energy Web X, decoded from the union of
/// `parachainStaking.nominatorState(accountId)` and
/// `parachainStaking.nominationScheduledRequests(candidate)` for each
/// active nomination.
struct ParachainAvnStakePosition {
    let nominator: AccountId
    let nominations: [Nomination]
    /// Sum of `amount` across every nomination in the list. Convenience
    /// field — re-derivable from `nominations` but stored so "total
    /// staked" labels don't rebuild it on every render.
    let totalLocked: BigUInt

    struct Nomination {
        let candidate: AccountId
        let candidateIdentity: String?
        let amount: BigUInt
        /// Scheduled unbond or revoke request, if any. `nil` means the
        /// nomination is fully active and there's nothing pending.
        let pendingRequest: PendingRequest?
    }

    struct PendingRequest {
        enum Action: Equatable {
            /// `scheduleNominatorUnbond(candidate, less)` — partial
            /// unbond for `less` wei.
            case unbond(less: BigUInt)
            /// `scheduleRevokeNomination(collator)` — full revoke.
            /// `amount` is the full staked balance at scheduling time,
            /// mirrored in `NominationScheduledRequests`.
            case revoke(amount: BigUInt)
        }

        let action: Action
        /// Era at which `executeNominationRequest` becomes valid.
        /// Read from the scheduled request's `whenExecutable` field.
        let executableAtEra: UInt32
    }
}
