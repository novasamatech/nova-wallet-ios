import Foundation
import BigInt
import SubstrateSdk

enum BlockchainWeightFactory {
    struct CallWeightConversionHandlers<T> {
        let v1Handler: (T, Substrate.WeightV1) throws -> T
        let v1P5Handler: (T, Substrate.WeightV1P5) throws -> T
        let v2Handler: (T, Substrate.WeightV2) throws -> T
    }

    struct CallWeightConversionParams {
        let path: CallCodingPath
        let argName: String
    }

    static func convertCallVersionedWeightInWeightLimitToJson(
        for params: CallWeightConversionParams,
        codingFactory: RuntimeCoderFactoryProtocol,
        weight: UInt64
    ) throws -> JSON? {
        let context = codingFactory.createRuntimeJsonContext().toRawContext()

        guard let callType = codingFactory.getCall(for: params.path) else {
            return nil
        }

        let optWeightType: String? = callType.mapArgumentTypeOf(
            params.argName,
            closure: { weightLimitType in
                guard let weightLimitNode = codingFactory.getTypeNode(for: weightLimitType) as? SiVariantNode else {
                    return nil
                }

                return weightLimitNode.typeMapping
                    .first { $0.name == Xcm.WeightLimitFields.limited }?
                    .node.typeName
            },
            defaultValue: nil
        )

        guard let weightType = optWeightType else {
            return nil
        }

        return try convertTypeVersionedWeight(
            for: weightType,
            codingFactory: codingFactory,
            handlers: .init(
                v1Handler: { _, weight in
                    try weight.toScaleCompatibleJSON(with: context)
                },
                v1P5Handler: { _, weight in
                    try weight.toScaleCompatibleJSON(with: context)
                },
                v2Handler: { _, weight in
                    try weight.toScaleCompatibleJSON(with: context)
                }
            ),
            builder: JSON.null,
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

        return try callType.mapArgumentTypeOf(
            params.argName,
            closure: { argumentType in
                try Self.convertTypeVersionedWeight(
                    for: argumentType,
                    codingFactory: codingFactory,
                    handlers: handlers,
                    builder: builder,
                    weight: weight
                )
            },
            defaultValue: builder
        )
    }

    static func convertTypeVersionedWeight<T>(
        for type: String,
        codingFactory: RuntimeCoderFactoryProtocol,
        handlers: CallWeightConversionHandlers<T>,
        builder: T,
        weight: UInt64
    ) throws -> T {
        // v1 require only uint64 or compact number weight
        let isV1 = codingFactory.isUInt64Type(type) || codingFactory.isCompactType(type)

        if isV1 {
            return try handlers.v1Handler(builder, .init(value: weight))
        } else {
            // version 1.5 contains only 1 field and v2 contains 2 fields
            let isV1P5 = codingFactory.isStructHasFieldsCount(type, count: 1)

            if isV1P5 {
                return try handlers.v1P5Handler(builder, .init(refTime: BigUInt(weight)))
            } else {
                return try handlers.v2Handler(builder, .init(refTime: BigUInt(weight), proofSize: 0))
            }
        }
    }
}
