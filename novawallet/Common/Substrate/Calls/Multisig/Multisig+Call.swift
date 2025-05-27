import Foundation
import SubstrateSdk
import BigInt

extension Multisig {
    struct AsMultiCall<Weight: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case maybeTimepoint = "maybe_timepoint"
            case call
            case maxWeight = "max_weight"
        }

        @StringCodable var threshold: UInt16
        let otherSignatories: [AccountId]
        @NullCodable var maybeTimepoint: MultisigTimepoint?
        let call: JSON
        let maxWeight: Weight

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

        let otherSignatories: [AccountId]
        let call: JSON

        func runtimeCall() throws -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "as_multi_threshold_1",
                args: self
            )
        }
    }

    struct ApproveAsMultiCall<Weight: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case maybeTimepoint = "maybe_timepoint"
            case callHash = "call_hash"
            case maxWeight = "max_weight"
        }

        @StringCodable var threshold: UInt16
        let otherSignatories: [AccountId]
        @NullCodable var maybeTimepoint: MultisigTimepoint?
        let callHash: Data
        let maxWeight: Weight

        func runtimeCall() throws -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "approve_as_multi",
                args: self
            )
        }
    }
}
