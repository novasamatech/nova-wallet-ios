import Foundation

extension MultisigPayloadCodingKey {
    enum Cancelled: String, MultisigCodingKeyProtocol {
        case multisigKey = "multisig"
        case signatoryKey = "canceller"
        case callHashKey = "callHash"
        case callDataKey = "callData"

        static var multisigAddress: Cancelled { .multisigKey }
        static var signatoryAddress: Cancelled { .signatoryKey }
        static var callHash: Cancelled { .callHashKey }
        static var callData: Cancelled { .callDataKey }
    }
}
