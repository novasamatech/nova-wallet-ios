import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    static var possibleModuleNames: [String] { ["XcmPallet", "PolkadotXcm"] }
    static var executeCallName: String { "execute" }

    struct ExecuteCallV1: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case message
            case maxWeight = "max_weight"
        }

        let message: Xcm.Message
        @StringCodable var maxWeight: BigUInt

        func runtimeCall(for moduleName: String) -> RuntimeCall<ExecuteCallV1> {
            RuntimeCall(moduleName: moduleName, callName: Xcm.executeCallName, args: self)
        }
    }

    struct ExecuteCallV2: Codable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case message
            case maxWeight = "max_weight"
        }

        let message: Xcm.Message
        let maxWeight: BlockchainWeight.WeightV2

        func runtimeCall(for moduleName: String) -> RuntimeCall<ExecuteCallV2> {
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
        let isV1 = codingFactory.getCall(for: path)?.isArgumentTypeOf(
            ExecuteCallV1.CodingKeys.maxWeight.rawValue
        ) { argumentType in
            codingFactory.isUInt64Type(argumentType)
        } ?? true

        if isV1 {
            let call = ExecuteCallV1(message: message, maxWeight: maxWeight)
            return try builder.adding(call: call.runtimeCall(for: module))
        } else {
            let call = ExecuteCallV2(
                message: message,
                maxWeight: .init(refTime: maxWeight, proofSize: 0)
            )

            return try builder.adding(call: call.runtimeCall(for: module))
        }
    }
}
