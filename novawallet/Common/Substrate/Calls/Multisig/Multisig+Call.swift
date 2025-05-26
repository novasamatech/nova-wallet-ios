import Foundation
import SubstrateSdk

extension Multisig {
    struct AsMultiCall<Weight: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case maybeTimepoint = "maybe_timepoint"
            case call
            case maxWeight = "max_weight"
        }

        let threshold: UInt16
        let otherSignatories: [AccountId]
        let maybeTimepoint: MultisigTimepoint?
        let call: JSON
        let maxWeight: Weight?

        init(
            threshold: UInt16,
            otherSignatories: [AccountId],
            maybeTimepoint: MultisigTimepoint?,
            call: JSON,
            maxWeight: Weight?
        ) {
            self.threshold = threshold
            self.otherSignatories = otherSignatories
            self.maybeTimepoint = maybeTimepoint
            self.call = call
            self.maxWeight = maxWeight
        }

        func runtimeCall() throws -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "as_multi",
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

        let threshold: UInt16
        let otherSignatories: [AccountId]
        let maybeTimepoint: MultisigTimepoint?
        let callHash: String
        let maxWeight: Weight?

        init(
            threshold: UInt16,
            otherSignatories: [AccountId],
            maybeTimepoint: MultisigTimepoint?,
            callHash: String,
            maxWeight: Weight?
        ) {
            self.threshold = threshold
            self.otherSignatories = otherSignatories
            self.maybeTimepoint = maybeTimepoint
            self.callHash = callHash
            self.maxWeight = maxWeight
        }

        func runtimeCall() throws -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "approve_as_multi",
                args: self
            )
        }
    }
}
