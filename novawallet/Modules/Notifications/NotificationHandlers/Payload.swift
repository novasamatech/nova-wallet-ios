import Foundation
import BigInt

struct NewMultisigPayload: Codable {
    enum CodingKeys: String, CodingKey {
        case multisigAddress = "multisig"
        case initiatorAddress = "initiator"
        case callHash = "call_hash"
        case callData
    }

    let multisigAddress: AccountAddress
    let initiatorAddress: AccountAddress
    @HexCodable var callHash: Substrate.CallHash
    let callData: HexCodable<Substrate.CallData>?
}

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

extension ReferendumStateUpdatePayload.Status {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let status = try container.decode(String.self)
        switch status {
        case "Created":
            self = .created
        case "Deciding":
            self = .deciding
        case "Confirming":
            self = .confirming
        case "Approved":
            self = .approved
        case "Rejected":
            self = .rejected
        case "TimedOut":
            self = .timedOut
        case "Cancelled":
            self = .cancelled
        case "Killed":
            self = .killed
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot initialize RawRepresentable from invalid String value \(status)"
            )
        }
    }
}
