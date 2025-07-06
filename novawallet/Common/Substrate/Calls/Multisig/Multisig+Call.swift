import Foundation
import SubstrateSdk
import BigInt

extension MultisigPallet {
    struct AsMultiCall<C: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case maybeTimepoint = "maybe_timepoint"
            case call
            case maxWeight = "max_weight"
        }

        @StringCodable var threshold: UInt16
        let otherSignatories: [BytesCodable]
        @NullCodable var maybeTimepoint: MultisigTimepoint?
        let call: C
        let maxWeight: Substrate.Weight

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: MultisigPallet.asMultiPath.moduleName,
                callName: MultisigPallet.asMultiPath.callName,
                args: self
            )
        }
    }

    static var asMultiPath: CallCodingPath {
        CallCodingPath(moduleName: Self.name, callName: "as_multi")
    }

    struct AsMultiThreshold1Call<C: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case otherSignatories = "other_signatories"
            case call
        }

        let otherSignatories: [BytesCodable]
        let call: C

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: MultisigPallet.asMultiThreshold1Path.moduleName,
                callName: MultisigPallet.asMultiThreshold1Path.callName,
                args: self
            )
        }
    }

    static var asMultiThreshold1Path: CallCodingPath {
        CallCodingPath(moduleName: Self.name, callName: "as_multi_threshold_1")
    }

    struct CancelAsMultiCall: Codable {
        enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case timepoint
            case callHash = "call_hash"
        }

        @StringCodable var threshold: UInt16
        let otherSignatories: [BytesCodable]
        let timepoint: MultisigTimepoint
        @BytesCodable var callHash: Substrate.CallHash

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "cancel_as_multi",
                args: self
            )
        }
    }
}
