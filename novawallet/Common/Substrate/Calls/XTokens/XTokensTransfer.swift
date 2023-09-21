import Foundation
import BigInt
import SubstrateSdk

extension XTokens {
    static let transferCallName = "transfer_multiasset"

    struct TransferCallV1: Codable {
        enum CodingKeys: String, CodingKey {
            case asset
            case destination = "dest"
            case destinationWeight = "dest_weight"
        }

        let asset: Xcm.VersionedMultiasset
        let destination: Xcm.VersionedMultilocation

        // must be set as maximum between reserve and destination
        @StringCodable var destinationWeight: BigUInt

        func runtimeCall(for module: String) -> RuntimeCall<Self> {
            RuntimeCall(moduleName: module, callName: XTokens.transferCallName, args: self)
        }

        func codingPath(for module: String) -> CallCodingPath {
            CallCodingPath(moduleName: module, callName: XTokens.transferCallName)
        }
    }

    struct TransferCallV2: Codable {
        enum CodingKeys: String, CodingKey {
            case asset
            case destination = "dest"
            case destinationWeightLimit = "dest_weight_limit"
        }

        static let callName = "transfer_multiasset"

        let asset: Xcm.VersionedMultiasset
        let destination: Xcm.VersionedMultilocation

        // must be set as maximum between reserve and destination
        let destinationWeightLimit: Xcm.WeightLimit<JSON>

        func runtimeCall(for module: String) -> RuntimeCall<Self> {
            RuntimeCall(moduleName: module, callName: XTokens.transferCallName, args: self)
        }

        func codingPath(for module: String) -> CallCodingPath {
            CallCodingPath(moduleName: module, callName: XTokens.transferCallName)
        }
    }

    static func appendTransferCall(
        asset: Xcm.VersionedMultiasset,
        destination: Xcm.VersionedMultilocation,
        weight: BigUInt,
        module: String,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> (ExtrinsicBuilderClosure, CallCodingPath) {
        let path = CallCodingPath(moduleName: module, callName: XTokens.transferCallName)

        guard let callType = codingFactory.getCall(for: path) else {
            return ({ $0 }, path)
        }

        let paramNameV1 = TransferCallV1.CodingKeys.destinationWeight.rawValue

        // v1 require only uint64 weight and v2 requires weight limit
        let isV1 = callType.isArgumentTypeOf(paramNameV1) { argumentType in
            codingFactory.isUInt64Type(argumentType)
        }

        if isV1 {
            let call = TransferCallV1(asset: asset, destination: destination, destinationWeight: weight)

            return ({ try $0.adding(call: call.runtimeCall(for: module)) }, path)
        } else {
            let call = TransferCallV2(
                asset: asset,
                destination: destination,
                destinationWeightLimit: .unlimited
            )

            return ({ try $0.adding(call: call.runtimeCall(for: module)) }, path)
        }
    }
}
