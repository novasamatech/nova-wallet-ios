import Foundation
@testable import novawallet
import SubstrateSdk
import XCTest

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

    static func decodeEvents(
        _ eventsHex: [String],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [Event] {
        let entry = try XCTUnwrap(codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath))

        let recordsHex = littleEndianHex(UInt8(eventsHex.count << 2)) +
            eventsHex.map { "00" + "00000000" + $0 + "00" }.joined()
        let decoder = try codingFactory.createDecoder(from: Data(hexString: recordsHex))
        let json = try decoder.read(type: entry.type.typeName)

        return try json.map(
            to: [EventRecord].self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ).map(\.event)
    }

    static func littleEndianHex<T: FixedWidthInteger>(_ value: T) -> String {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }.toHex()
    }
}
