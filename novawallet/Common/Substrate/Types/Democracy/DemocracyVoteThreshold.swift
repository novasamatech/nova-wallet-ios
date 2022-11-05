import Foundation

extension Democracy {
    enum VoteThreshold: Decodable {
        /// A supermajority of approvals is needed to pass this vote.
        case superMajorityApprove

        /// A supermajority of rejects is needed to fail this vote.
        case superMajorityAgainst

        /// A simple majority of approvals is needed to pass this vote.
        case simpleMajority

        case unknown

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "SuperMajorityApprove":
                self = .superMajorityApprove
            case "superMajorityAgainst":
                self = .superMajorityAgainst
            case "SimpleMajority":
                self = .simpleMajority
            default:
                self = .unknown
            }
        }
    }
}
