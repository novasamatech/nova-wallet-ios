import Foundation

enum BlockchainWeightFactory {
    struct CallWeightConversionHandlers<T> {
        let v1Handler: (T) throws -> T
        let v1P5Handler: (T) throws -> T
        let v2Handler: (T) throws -> T
    }

    static func convertCallVersionedWeight<T>(
        for path: CallCodingPath,
        paramName: String,
        codingFactory: RuntimeCoderFactoryProtocol,
        handlers: CallWeightConversionHandlers<T>,
        builder: T
    ) throws -> T {
        guard let callType = codingFactory.getCall(for: path) else {
            return builder
        }

        // v1 require only uint64 weight
        let isV1 = callType.isArgumentTypeOf(paramName) { argumentType in
            codingFactory.isUInt64Type(argumentType)
        }

        if isV1 {
            return try handlers.v1Handler(builder)
        } else {
            // verision 1.5 contains only 1 field and v2 contains 2 fields
            let isV1P5 = callType.isArgumentTypeOf(paramName) { argumentType in
                codingFactory.isStructHasFieldsCount(argumentType, count: 1)
            }

            if isV1P5 {
                return try handlers.v1P5Handler(builder)
            } else {
                return try handlers.v2Handler(builder)
            }
        }
    }
}
