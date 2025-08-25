import Foundation
import SubstrateSdk

enum XcmMessageSerializer {
    static func serialize(
        message: XcmUni.VersionedMessage,
        type: String,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Data {
        let encoder = codingFactory.createEncoder()
        let context = codingFactory.createRuntimeJsonContext()

        try encoder.append(message, ofType: type, with: context.toRawContext())

        return try encoder.encode()
    }
}
