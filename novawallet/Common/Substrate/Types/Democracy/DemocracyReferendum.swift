import Foundation
import SubstrateSdk
import BigInt

extension Democracy {
    struct Tally: Decodable {
        /// The number of aye votes, expressed in terms of post-conviction lock-vote.
        @StringCodable var ayes: BigUInt

        /// The number of nay votes, expressed in terms of post-conviction lock-vote.
        @StringCodable var nays: BigUInt

        /// The amount of funds currently expressing its opinion. Pre-conviction.
        @StringCodable var turnout: BigUInt
    }

    struct OngoingStatus: Decodable {
        @StringCodable var end: BlockNumber
        @StringCodable var delay: BlockNumber
        let threshold: Democracy.VoteThreshold
        let tally: Tally
    }

    struct FinishedStatus: Decodable {
        enum CodingKeys: String, CodingKey {
            case approved = "0"
            case end = "1"
        }

        let approved: Bool
        @StringCodable var end: BlockNumber
    }

    enum ReferendumInfo: Decodable {
        case ongoing(OngoingStatus)
        case finished(FinishedStatus)
        case unknown

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Ongoing":
                let status = try container.decode(OngoingStatus.self)
                self = .ongoing(status)
            case "Finished":
                let status = try container.decode(FinishedStatus.self)
                self = .finished(status)
            default:
                self = .unknown
            }
        }
    }

}
