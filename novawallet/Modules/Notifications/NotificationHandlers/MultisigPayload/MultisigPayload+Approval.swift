import Foundation

extension MultisigPayloadCodingKey {
    enum Approval: String, MultisigCodingKeyProtocol {
        case multisigKey = "multisig"
        case signatoryKey = "approver"
        case callHashKey = "callHash"
        case callDataKey = "callData"

        static var multisigAddress: Approval { .multisigKey }
        static var signatoryAddress: Approval { .signatoryKey }
        static var callHash: Approval { .callHashKey }
        static var callData: Approval { .callDataKey }
    }
}
