import Foundation
import BigInt

struct StakingRewardPayload: Codable {
    let recipient: AccountAddress
    let amount: String
}

struct NewReleasePayload: Codable {
    let version: String
}

struct NewReferendumPayload: Codable {
    let referendumId: Referenda.ReferendumIndex

    var referendumNumber: String {
        "\(referendumId)"
    }
}

struct ReferendumStateUpdatePayload: Decodable {
    enum CodingKeys: String, CodingKey {
        case referendumId
        case fromStatus = "from"
        case toStatus = "to"
    }

    let referendumId: Referenda.ReferendumIndex
    let fromStatus: Status?
    let toStatus: Status

    enum Status: String, Decodable {
        case created
        case deciding
        case confirming
        case approved
        case rejected
        case cancelled
        case timedOut
        case killed
    }

    var referendumNumber: String {
        "\(referendumId)"
    }
}

struct NotificationTransferPayload: Decodable {
    let sender: AccountAddress?
    let recipient: AccountAddress?
    let amount: String
    let assetId: String?
}
