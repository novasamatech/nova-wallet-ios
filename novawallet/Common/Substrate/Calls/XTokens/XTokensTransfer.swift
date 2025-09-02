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

        let asset: XcmUni.VersionedAsset
        let destination: XcmUni.VersionedLocation

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

        let asset: XcmUni.VersionedAsset
        let destination: XcmUni.VersionedLocation

        // must be set as maximum between reserve and destination
        let destinationWeightLimit: Xcm.WeightLimit<JSON>

        func runtimeCall(for module: String) -> RuntimeCall<Self> {
            RuntimeCall(moduleName: module, callName: XTokens.transferCallName, args: self)
        }

        func codingPath(for module: String) -> CallCodingPath {
            CallCodingPath(moduleName: module, callName: XTokens.transferCallName)
        }
    }

    enum TransferDerivationError: Error {
        case callNotFound(CallCodingPath)
        case destinationWeightRequired
    }

    static func appendTransferCall(
        asset: XcmUni.VersionedAsset,
        destination: XcmUni.VersionedLocation,
        module: String,
        weightOption: XcmTransferMetadata.Fee,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> RuntimeCallCollecting {
        let path = CallCodingPath(moduleName: module, callName: XTokens.transferCallName)

        guard let callType = codingFactory.getCall(for: path) else {
            throw TransferDerivationError.callNotFound(path)
        }

        let paramNameV1 = TransferCallV1.CodingKeys.destinationWeight.rawValue

        // v1 require only uint64 weight and v2 requires weight limit
        let isV1 = callType.isArgumentTypeOf(paramNameV1) { argumentType in
            codingFactory.isUInt64Type(argumentType)
        }

        if isV1 {
            guard case let .legacy(legacyFee) = weightOption else {
                throw TransferDerivationError.destinationWeightRequired
            }

            let args = TransferCallV1(
                asset: asset,
                destination: destination,
                destinationWeight: legacyFee.maxWeight
            )

            return RuntimeCallCollector(call: RuntimeCall(path: path, args: args))
        } else {
            let args = TransferCallV2(
                asset: asset,
                destination: destination,
                destinationWeightLimit: .unlimited
            )

            return RuntimeCallCollector(call: RuntimeCall(path: path, args: args))
        }
    }
}
