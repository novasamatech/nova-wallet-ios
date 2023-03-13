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
        let paramName = ExecuteCall<BigUInt>.CodingKeys.maxWeight.rawValue

        return try BlockchainWeightFactory.convertCallVersionedWeight(
            for: path,
            paramName: paramName,
            codingFactory: codingFactory,
            handlers: .init(
                v1Handler: { builder in
                    let call = ExecuteCall(message: message, maxWeight: StringScaleMapper(value: maxWeight))
                    return try builder.adding(call: call.runtimeCall(for: module))
                },
                v1P5Handler: { builder in
                    let call = ExecuteCall(
                        message: message,
                        maxWeight: BlockchainWeight.WeightV1P5(refTime: UInt64(maxWeight))
                    )

                    return try builder.adding(call: call.runtimeCall(for: module))
                },
                v2Handler: { builder in
                    let call = ExecuteCall(
                        message: message,
                        maxWeight: BlockchainWeight.WeightV2(refTime: maxWeight, proofSize: 0)
                    )

                    return try builder.adding(call: call.runtimeCall(for: module))
                }
            ),
            builder: builder
        )
    }
}
