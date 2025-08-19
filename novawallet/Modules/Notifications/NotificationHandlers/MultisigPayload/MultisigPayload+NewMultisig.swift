import Foundation

extension MultisigPayloadCodingKey {
    enum NewMultisig: String, MultisigCodingKeyProtocol {
        case multisigKey = "multisig"
        case signatoryKey = "initiator"
        case callHashKey = "callHash"
        case callDataKey = "callData"

        static var multisigAddress: NewMultisig { .multisigKey }
        static var signatoryAddress: NewMultisig { .signatoryKey }
        static var callHash: NewMultisig { .callHashKey }
        static var callData: NewMultisig { .callDataKey }
    }
}
