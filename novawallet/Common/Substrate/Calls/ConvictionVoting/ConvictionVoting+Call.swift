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

    struct RemoveVoteCall: Codable {
        enum CodingKeys: String, CodingKey {
            case track = "class"
            case index
        }

        @OptionStringCodable var track: Referenda.TrackId?
        @StringCodable var index: Referenda.ReferendumIndex

        var runtimeCall: RuntimeCall<Self> {
            RuntimeCall(moduleName: "ConvictionVoting", callName: "remove_vote", args: self)
        }
    }

    struct UnlockCall: Codable {
        enum CodingKeys: String, CodingKey {
            case track = "class"
            case target
        }

        @StringCodable var track: Referenda.TrackId
        let target: MultiAddress

        var runtimeCall: RuntimeCall<Self> {
            RuntimeCall(moduleName: "ConvictionVoting", callName: "unlock", args: self)
        }
    }
}
