import Foundation
import SubstrateSdk
import BigInt

enum ConvictionVoting {
    typealias PollIndex = UInt32

    static var lockId: String = "pyconvot"

    static let name = "ConvictionVoting"

    enum Conviction: UInt8, Codable, Equatable {
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
                return 3 * balance
            case .locked4x:
                return 4 * balance
            case .locked5x:
                return 5 * balance
            case .locked6x:
                return 6 * balance
            case .unknown:
                return nil
            }
        }

        func conviction(for period: Moment) -> Moment? {
            switch self {
            case .none:
                return 0
            case .locked1x:
                return period
            case .locked2x:
                return 2 * period
            case .locked3x:
                return 4 * period
            case .locked4x:
                return 8 * period
            case .locked5x:
                return 16 * period
            case .locked6x:
                return 32 * period
            case .unknown:
                return nil
            }
        }

        var decimalValue: Decimal? {
            switch self {
            case .none:
                return 0.1
            case .locked1x:
                return 1
            case .locked2x:
                return 2
            case .locked3x:
                return 3
            case .locked4x:
                return 4
            case .locked5x:
                return 5
            case .locked6x:
                return 6
            case .unknown:
                return nil
            }
        }

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "None":
                self = .none
            case "Locked1x":
                self = .locked1x
            case "Locked2x":
                self = .locked2x
            case "Locked3x":
                self = .locked3x
            case "Locked4x":
                self = .locked4x
            case "Locked5x":
                self = .locked5x
            case "Locked6x":
                self = .locked6x
            default:
                self = .unknown
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            let type: String

            switch self {
            case .none:
                type = "None"
            case .locked1x:
                type = "Locked1x"
            case .locked2x:
                type = "Locked2x"
            case .locked3x:
                type = "Locked3x"
            case .locked4x:
                type = "Locked4x"
            case .locked5x:
                type = "Locked5x"
            case .locked6x:
                type = "Locked6x"
            case .unknown:
                throw EncodingError.invalidValue(
                    self,
                    EncodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Can't encode unknown value"
                    )
                )
            }

            try container.encode(type)
            try container.encodeNil()
        }
    }

    struct Vote: Codable, Equatable {
        static let ayeMask: UInt8 = 1 << 7
        static var voteMask: UInt8 { ~ayeMask }

        let aye: Bool
        let conviction: Conviction

        init(aye: Bool, conviction: Conviction) {
            self.aye = aye
            self.conviction = conviction
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let compactVote = try container.decode(StringScaleMapper<UInt8>.self).value

            aye = (compactVote & Self.ayeMask) == Self.ayeMask
            let rawConviction = compactVote & Self.voteMask

            conviction = Conviction(rawValue: rawConviction) ?? .unknown
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            let rawConviction = conviction.rawValue
            let compactVote = aye ? Self.ayeMask | rawConviction : rawConviction

            try container.encode(StringScaleMapper(value: compactVote))
        }
    }

    struct AccountVoteStandard: Codable, Equatable {
        let vote: Vote
        @StringCodable var balance: BigUInt
    }

    struct AccountVoteSplit: Codable, Equatable {
        @StringCodable var aye: BigUInt
        @StringCodable var nay: BigUInt
    }

    struct AccountVoteSplitAbstain: Codable, Equatable {
        @StringCodable var aye: BigUInt
        @StringCodable var nay: BigUInt
        @StringCodable var abstain: BigUInt
    }

    enum AccountVote: Codable {
        static let standardField = "Standard"
        static let splitField = "Split"
        static let splitAbstainField = "SplitAbstain"

        case unknown

        /// A standard vote, one-way (approve or reject) with a given amount of conviction.
        case standard(_ vote: AccountVoteStandard)

        /**
         *  A split vote with balances given for both ways, and with no conviction, useful for
         *  parachains when voting.
         */
        case split(_ vote: AccountVoteSplit)

        /**
         *  A split vote with balances given for both ways as well as abstentions, and with no
         *  conviction, useful for parachains when voting, other off-chain aggregate accounts and
         *  individuals who wish to abstain.
         */
        case splitAbstain(_ vote: AccountVoteSplitAbstain)

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case Self.standardField:
                let vote = try container.decode(AccountVoteStandard.self)
                self = .standard(vote)
            case Self.splitField:
                let vote = try container.decode(AccountVoteSplit.self)
                self = .split(vote)
            case Self.splitAbstainField:
                let vote = try container.decode(AccountVoteSplitAbstain.self)
                self = .splitAbstain(vote)
            default:
                self = .unknown
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .standard(model):
                try container.encode(Self.standardField)
                try container.encode(model)
            case let .split(model):
                try container.encode(Self.splitField)
                try container.encode(model)
            case let .splitAbstain(model):
                try container.encode(Self.splitAbstainField)
                try container.encode(model)
            case .unknown:
                throw EncodingError.invalidValue(
                    self,
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Account vote type is unknown"
                    )
                )
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

        var exists: Bool {
            unlockAt > 0 || amount > 0
        }

        static var notExisting: PriorLock {
            PriorLock(unlockAt: 0, amount: 0)
        }
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
        @BytesCodable var target: AccountId

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
