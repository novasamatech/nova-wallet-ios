import Foundation
import SubstrateSdk
import BigInt

extension Treasury {
    static var approveProposalCallPath: CallCodingPath {
        CallCodingPath(moduleName: "Treasury", callName: "approve_proposal")
    }

    struct ApproveProposal: Decodable {
        enum CodingKeys: String, CodingKey {
            case proposalId = "proposal_id"
        }

        @StringCodable var proposalId: ProposalIndex
    }

    static var spendCallPath: CallCodingPath {
        CallCodingPath(moduleName: "Treasury", callName: "spend")
    }

    static var spendLocalCallPath: CallCodingPath {
        CallCodingPath(moduleName: "Treasury", callName: "spend_local")
    }

    struct SpendCall: Decodable {
        @StringCodable var amount: BigUInt
        let beneficiary: MultiAddress
    }
}
