import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    static var possibleModuleNames: [String] { ["XcmPallet", "PolkadotXcm"] }
    static var executeCallName: String { "execute" }

    struct ExecuteCall<M: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case message
            case maxWeight = "max_weight"
        }

        let message: XcmUni.VersionedMessage
        let maxWeight: M

        func runtimeCall(for moduleName: String) -> RuntimeCall<Self> {
            RuntimeCall(moduleName: moduleName, callName: Xcm.executeCallName, args: self)
        }
    }

    static func appendExecuteCall(
        for message: XcmUni.VersionedMessage,
        maxWeight: BigUInt,
        module: String,
        codingFactory: RuntimeCoderFactoryProtocol,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let path = CallCodingPath(moduleName: module, callName: Xcm.executeCallName)
        let paramName = ExecuteCall<BigUInt>.CodingKeys.maxWeight.rawValue

        return try BlockchainWeightFactory.convertCallVersionedWeight(
            for: .init(path: path, argName: paramName),
            codingFactory: codingFactory,
            handlers: .init(
                v1Handler: { builder, weight in
                    let call = ExecuteCall(message: message, maxWeight: weight)
                    return try builder.adding(call: call.runtimeCall(for: module))
                },
                v1P5Handler: { builder, weight in
                    let call = ExecuteCall(message: message, maxWeight: weight)
                    return try builder.adding(call: call.runtimeCall(for: module))
                },
                v2Handler: { builder, weight in
                    let call = ExecuteCall(message: message, maxWeight: weight)
                    return try builder.adding(call: call.runtimeCall(for: module))
                }
            ),
            builder: builder,
            weight: UInt64(maxWeight)
        )
    }
}
