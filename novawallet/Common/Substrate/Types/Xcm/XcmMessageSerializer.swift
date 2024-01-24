import Foundation
import SubstrateSdk

enum XcmMessageSerializer {
    static func serialize(
        message: Xcm.Message,
        type: String,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Data {
        let encoder = codingFactory.createEncoder()
        let context = codingFactory.createRuntimeJsonContext()

        try encoder.append(message, ofType: type, with: context.toRawContext())

        return try encoder.encode()
    }
}
