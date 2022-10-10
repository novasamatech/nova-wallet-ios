import Foundation
import SubstrateSdk
import BigInt

enum ConvictionVoting {
    typealias PollIndex = UInt32

    enum Conviction: UInt8, Decodable {
        /// 0.1x votes, unlocked.
        case none
        /// 1x votes, locked for an enactment period following a successful vote.
        case locked1x
        /// 2x votes, locked for 2x enactment periods following a successful vote.
        case locked2x
        /// 3x votes, locked for 4x...
        case locked3x
        /// 4x votes, locked for 8x...
        case locked4x
        /// 5x votes, locked for 16x...
        case locked5x
        /// 6x votes, locked for 32x...
        case locked6x

        case unknown

        func votes(for balance: BigUInt) -> BigUInt? {
            switch self {
            case .none:
                return balance / 10
            case .locked1x:
                return balance
            case .locked2x:
                return 2 * balance
            case .locked3x:
                return 4 * balance
            case .locked4x:
                return 8 * balance
            case .locked5x:
                return 16 * balance
            case .locked6x:
                return 32 * balance
            case .unknown:
                return nil
            }
        }
    }

    struct Vote: Decodable {
        static let ayeMask: UInt8 = 1 << 7
        static var voteMask: UInt8 { ~ayeMask }

        let aye: Bool
        let conviction: Conviction

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let compactVote = try container.decode(StringScaleMapper<UInt8>.self).value

            aye = (compactVote & Self.ayeMask) == Self.ayeMask
            let rawConviction = compactVote & Self.voteMask

            conviction = Conviction(rawValue: rawConviction) ?? .unknown
        }
    }

    struct AccountVoteStandard: Decodable {
        let vote: Vote
        @StringCodable var balance: BigUInt
    }

    struct AccountVoteSplit: Decodable {
        @StringCodable var aye: BigUInt
        @StringCodable var nay: BigUInt
    }

    enum AccountVote: Decodable {
        case unknown

        /// A standard vote, one-way (approve or reject) with a given amount of conviction.
        case standard(_ vote: AccountVoteStandard)

        /**
         *  A split vote with balances given for both ways, and with no conviction, useful for
         *  parachains when voting.
         */
        case split(_ vote: AccountVoteSplit)

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Standard":
                let vote = try container.decode(AccountVoteStandard.self)
                self = .standard(vote)
            case "Split":
                let vote = try container.decode(AccountVoteSplit.self)
                self = .split(vote)
            default:
                self = .unknown
            }
        }
    }

    struct Delegations: Decodable {
        /// The number of votes (this is post-conviction).
        @StringCodable var votes: BigUInt

        /// The amount of raw capital, used for the support.
        @StringCodable var capital: BigUInt
    }

    struct PriorLock: Decodable {
        enum CodingKeys: String, CodingKey {
            case unlockAt = "0"
            case amount = "1"
        }

        @StringCodable var unlockAt: BlockNumber
        @StringCodable var amount: BigUInt
    }

    struct CastingVotes: Decodable {
        let pollIndex: PollIndex
        let accountVote: AccountVote

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            pollIndex = try container.decode(StringScaleMapper<PollIndex>.self).value
            accountVote = try container.decode(AccountVote.self)
        }
    }

    struct Casting: Decodable {
        /// The current votes of the account
        let votes: [CastingVotes]

        /// The total amount of delegations that this account has received, post-conviction-weighting
        let delegations: Delegations

        /// Any pre-existing locks from past voting/delegating activity.
        let prior: PriorLock
    }

    struct Delegating: Decodable {
        /// The amount of balance delegated.
        @StringCodable var balance: BigUInt

        /// The account to which the voting power is delegated.
        let target: AccountId

        /**
         * The conviction with which the voting power is delegated. When this gets undelegated, the
         * relevant lock begins.
         */
        let conviction: Conviction

        /// The total amount of delegations that this account has received, post-conviction-weighting.
        let delegations: Delegations

        /// Any pre-existing locks from past voting/delegating activity.
        let prior: PriorLock
    }

    enum Voting: Decodable {
        case unknown
        case casting(_ voting: Casting)
        case delegating(_ voting: Delegating)

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Casting":
                let voting = try container.decode(Casting.self)
                self = .casting(voting)
            case "Delegating":
                let voting = try container.decode(Delegating.self)
                self = .delegating(voting)
            default:
                self = .unknown
            }
        }
    }
}
