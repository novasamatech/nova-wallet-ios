import Foundation
import SubstrateSdk

extension ConvictionVoting {
    struct VoteCall: Codable {
        enum CodingKeys: String, CodingKey {
            case referendumIndex = "poll_index"
            case vote
        }

        @StringCodable var referendumIndex: Referenda.ReferendumIndex
        let vote: ConvictionVoting.AccountVote

        var runtimeCall: RuntimeCall<Self> {
            RuntimeCall(moduleName: "ConvictionVoting", callName: "vote", args: self)
        }
    }
}
