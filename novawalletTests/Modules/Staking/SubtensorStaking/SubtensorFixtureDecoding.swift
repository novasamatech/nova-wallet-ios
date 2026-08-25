import Foundation
@testable import novawallet
import SubstrateSdk

enum SubtensorFixtureDecoding {
    static func decodeRuntimeApiResult<T: Decodable>(
        from hex: String,
        path: StateCallPath,
        codingFactory: RuntimeCoderFactoryProtocol? = nil
    ) throws -> T {
        let factory = try codingFactory ?? RuntimeCodingServiceStub.createBittensorCodingFactory()

        let runtimeApi = try factory.metadata.getRuntimeApiMethodOrError(
            for: path.module,
            methodName: path.method
        )

        let decoder = StateCallResultFromTypeNameDecoder<T>(typeName: runtimeApi.method.output.asTypeId())

        return try decoder.decode(data: try Data(hexString: hex), using: factory)
    }
}
