import Foundation
import SubstrateSdk

extension Democracy {
    struct VoteCall: Codable {
        enum CodingKeys: String, CodingKey {
            case referendumIndex = "ref_index"
            case vote
        }

        @StringCodable var referendumIndex: Referenda.ReferendumIndex
        let vote: ConvictionVoting.AccountVote

        var runtimeCall: RuntimeCall<Self> {
            RuntimeCall(moduleName: "Democracy", callName: "vote", args: self)
        }
    }

    struct RemoveVoteCall: Codable {
        @StringCodable var index: Referenda.ReferendumIndex

        var runtimeCall: RuntimeCall<Self> {
            RuntimeCall(moduleName: "Democracy", callName: "remove_vote", args: self)
        }
    }

    struct UnlockCall: Codable {
        let target: MultiAddress

        var runtimeCall: RuntimeCall<Self> {
            RuntimeCall(moduleName: "Democracy", callName: "unlock", args: self)
        }
    }
}
