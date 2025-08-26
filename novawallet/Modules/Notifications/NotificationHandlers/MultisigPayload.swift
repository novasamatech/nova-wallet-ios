import Foundation

protocol MultisigPayloadProtocol: Codable {
    var multisigAddress: AccountAddress { get }
    var signatoryAddress: AccountAddress { get }
    var callHash: Substrate.CallHash { get }
    var callData: Substrate.CallData? { get }
    var approvals: Int? { get }
}

extension MultisigPayloadProtocol {
    var approvals: Int? { nil }
}

struct NewMultisigPayload: MultisigPayloadProtocol {
    enum CodingKeys: String, CodingKey {
        case multisigAddress = "multisig"
        case signatoryAddress = "initiator"
        case callHash
        case callData
    }

    let multisigAddress: AccountAddress
    let signatoryAddress: AccountAddress
    @HexCodable var callHash: Substrate.CallHash
    @OptionHexCodable var callData: Substrate.CallData?
}

struct ApprovalMultisigPayload: MultisigPayloadProtocol {
    enum CodingKeys: String, CodingKey {
        case multisigAddress = "multisig"
        case signatoryAddress = "approver"
        case callHash
        case callData
        case approvals
    }

    let multisigAddress: AccountAddress
    let signatoryAddress: AccountAddress
    @HexCodable var callHash: Substrate.CallHash
    @OptionHexCodable var callData: Substrate.CallData?
    let approvals: Int?
}

typealias ExecutedMultisigPayload = ApprovalMultisigPayload

struct CancelledMultisigPayload: MultisigPayloadProtocol {
    enum CodingKeys: String, CodingKey {
        case multisigAddress = "multisig"
        case signatoryAddress = "canceller"
        case callHash
        case callData
    }

    let multisigAddress: AccountAddress
    let signatoryAddress: AccountAddress
    @HexCodable var callHash: Substrate.CallHash
    @OptionHexCodable var callData: Substrate.CallData?
}
