import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    static var possibleModuleNames: [String] { ["XcmPallet", "PolkadotXcm"] }
    static var executeCallName: String { "execute" }

    struct ExecuteCall<M: Codable>: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case message
            case maxWeight = "max_weight"
        }

        let message: Xcm.Message
        let maxWeight: M

        func runtimeCall(for moduleName: String) -> RuntimeCall<Self> {
            RuntimeCall(moduleName: moduleName, callName: Xcm.executeCallName, args: self)
        }
    }

    static func appendExecuteCall(
        for message: Xcm.Message,
        maxWeight: BigUInt,
        module: String,
        codingFactory: RuntimeCoderFactoryProtocol,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let path = CallCodingPath(moduleName: module, callName: Xcm.executeCallName)

        guard let callType = codingFactory.getCall(for: path) else {
            return builder
        }

        let paramName = ExecuteCall<BigUInt>.CodingKeys.maxWeight.rawValue

        // v1 require only uint64 weight
        let isV1 = callType.isArgumentTypeOf(paramName) { argumentType in
            codingFactory.isUInt64Type(argumentType)
        }

        if isV1 {
            let call = ExecuteCall(message: message, maxWeight: StringScaleMapper(value: maxWeight))
            return try builder.adding(call: call.runtimeCall(for: module))
        } else {
            // verision 1.5 contains only 1 field and v2 contains 2 fields
            let isV1P5 = callType.isArgumentTypeOf(paramName) { argumentType in
                codingFactory.isStructHasFieldsCount(argumentType, count: 1)
            }

            if isV1P5 {
                let call = ExecuteCall(
                    message: message,
                    maxWeight: BlockchainWeight.WeightV1P5(refTime: UInt64(maxWeight))
                )

                return try builder.adding(call: call.runtimeCall(for: module))
            } else {
                let call = ExecuteCall(
                    message: message,
                    maxWeight: BlockchainWeight.WeightV2(refTime: maxWeight, proofSize: 0)
                )

                return try builder.adding(call: call.runtimeCall(for: module))
            }
        }
    }
}
