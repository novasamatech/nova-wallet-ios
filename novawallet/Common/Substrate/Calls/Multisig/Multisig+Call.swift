import Foundation
import SubstrateSdk
import BigInt

extension MultisigPallet {
    struct AsMultiCall: Codable {
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
        let call: JSON
        let maxWeight: Substrate.WeightV2

        func runtimeCall() throws -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "as_multi",
                args: self
            )
        }
    }

    struct AsMultiThreshold1Call: Codable {
        enum CodingKeys: String, CodingKey {
            case otherSignatories = "other_signatories"
            case call
        }

        let otherSignatories: [BytesCodable]
        let call: JSON

        func runtimeCall() throws -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "as_multi_threshold_1",
                args: self
            )
        }
    }

    struct ApproveAsMultiCall: Codable {
        enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case maybeTimepoint = "maybe_timepoint"
            case callHash = "call_hash"
            case maxWeight = "max_weight"
        }

        @StringCodable var threshold: UInt16
        let otherSignatories: [BytesCodable]
        @NullCodable var maybeTimepoint: MultisigTimepoint?
        let callHash: Substrate.CallHash
        let maxWeight: Substrate.WeightV2

        func runtimeCall() throws -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "approve_as_multi",
                args: self
            )
        }
    }
}
