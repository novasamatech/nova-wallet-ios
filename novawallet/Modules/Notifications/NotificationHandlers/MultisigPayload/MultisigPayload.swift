import Foundation

protocol MultisigCodingKeyProtocol: CodingKey {
    static var multisigAddress: Self { get }
    static var signatoryAddress: Self { get }
    static var callHash: Self { get }
    static var callData: Self { get }
}

protocol MultisigPayloadProtocol: Codable {
    var multisigAddress: AccountAddress { get }
    var signatoryAddress: AccountAddress { get }
    var callHash: Substrate.CallHash { get }
    var callData: Substrate.CallData? { get }
}

struct MultisigPayload<Keys: MultisigCodingKeyProtocol>: MultisigPayloadProtocol {
    let multisigAddress: AccountAddress
    let signatoryAddress: AccountAddress
    @HexCodable var callHash: Substrate.CallHash
    @OptionHexCodable var callData: Substrate.CallData?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        multisigAddress = try container.decode(AccountAddress.self, forKey: Keys.multisigAddress)
        signatoryAddress = try container.decode(AccountAddress.self, forKey: Keys.signatoryAddress)
        _callHash = try container.decode(HexCodable<Substrate.CallHash>.self, forKey: Keys.callHash)
        _callData = try container.decode(OptionHexCodable<Substrate.CallData>.self, forKey: Keys.callData)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(multisigAddress, forKey: Keys.multisigAddress)
        try container.encode(signatoryAddress, forKey: Keys.signatoryAddress)
        try container.encode(callHash, forKey: Keys.callHash)
        try container.encode(callData, forKey: Keys.callData)
    }
}

enum MultisigPayloadCodingKey {}

typealias NewMultisigPayload = MultisigPayload<MultisigPayloadCodingKey.NewMultisig>
typealias ApprovalMultisigPayload = MultisigPayload<MultisigPayloadCodingKey.Approval>
typealias ExecutedMultisigPayload = MultisigPayload<MultisigPayloadCodingKey.Execute>
typealias CancelledMultisigPayload = MultisigPayload<MultisigPayloadCodingKey.Cancelled>
