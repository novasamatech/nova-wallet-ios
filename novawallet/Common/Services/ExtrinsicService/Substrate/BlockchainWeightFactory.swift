import Foundation
import BigInt
import SubstrateSdk

enum BlockchainWeightFactory {
    struct CallWeightConversionHandlers<T> {
        let v1Handler: (T, BlockchainWeight.WeightV1) throws -> T
        let v1P5Handler: (T, BlockchainWeight.WeightV1P5) throws -> T
        let v2Handler: (T, BlockchainWeight.WeightV2) throws -> T
    }

    struct CallWeightConversionParams {
        let path: CallCodingPath
        let argName: String
    }

    static func convertExecuteCallWeightTypeToJson(
        module: String,
        codingFactory: RuntimeCoderFactoryProtocol,
        weight: UInt64
    ) throws -> JSON {
        try convertCallVersionedWeightToJson(
            for: .init(
                path: .init(moduleName: module, callName: Xcm.executeCallName),
                argName: Xcm.ExecuteCall<BigUInt>.CodingKeys.maxWeight.rawValue
            ),
            codingFactory: codingFactory,
            weight: weight
        )
    }

    static func convertCallVersionedWeightToJson(
        for params: CallWeightConversionParams,
        codingFactory: RuntimeCoderFactoryProtocol,
        weight: UInt64
    ) throws -> JSON {
        let context = codingFactory.createRuntimeJsonContext().toRawContext()

        return try convertCallVersionedWeight(
            for: params,
            codingFactory: codingFactory,
            handlers: .init(
                v1Handler: { _, weight in
                    try weight.toScaleCompatibleJSON(with: context)
                }, v1P5Handler: { _, weight in
                    try weight.toScaleCompatibleJSON(with: context)
                }, v2Handler: { _, weight in
                    try weight.toScaleCompatibleJSON(with: context)
                }
            ), builder: .null,
            weight: weight
        )
    }

    static func convertCallVersionedWeight<T>(
        for params: CallWeightConversionParams,
        codingFactory: RuntimeCoderFactoryProtocol,
        handlers: CallWeightConversionHandlers<T>,
        builder: T,
        weight: UInt64
    ) throws -> T {
        guard let callType = codingFactory.getCall(for: params.path) else {
            return builder
        }

        // v1 require only uint64 weight
        let isV1 = callType.isArgumentTypeOf(params.argName) { argumentType in
            codingFactory.isUInt64Type(argumentType)
        }

        if isV1 {
            return try handlers.v1Handler(builder, .init(value: weight))
        } else {
            // verision 1.5 contains only 1 field and v2 contains 2 fields
            let isV1P5 = callType.isArgumentTypeOf(params.argName) { argumentType in
                codingFactory.isStructHasFieldsCount(argumentType, count: 1)
            }

            if isV1P5 {
                return try handlers.v1P5Handler(builder, .init(refTime: weight))
            } else {
                return try handlers.v2Handler(builder, .init(refTime: BigUInt(weight), proofSize: 0))
            }
        }
    }
}
