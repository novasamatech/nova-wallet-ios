import BigInt
import Foundation
import SubstrateSdk

struct StakingRewardPayload: Codable {
    let recipient: AccountAddress
    @StringCodable var amount: BigUInt
}

struct NewReleasePayload: Codable {
    let version: String
}

struct NewReferendumPayload: Codable {
    let referendumId: UInt

    var referendumNumber: String {
        "#\(referendumId)"
    }
}

struct ReferendumStateUpdatePayload: Codable {
    let referendumId: UInt
    let from: Status?
    let to: Status

    enum Status: String, Codable {
        case created
        case deciding
        case confirming
        case approved
        case rejected

        // TODO: localize
        func description(for _: Locale?) -> String {
            switch self {
            case .created:
                return "Created"
            case .deciding:
                return "Deciding"
            case .confirming:
                return "Confirming"
            case .approved:
                return "Approved"
            case .rejected:
                return "Rejected"
            }
        }
    }

    var referendumNumber: String {
        "#\(referendumId)"
    }
}

struct NotificationTransferPayload: Decodable {
    let sender: AccountAddress?
    let recipient: AccountAddress?
    @StringCodable var amount: BigUInt
    let assetId: String?
}
