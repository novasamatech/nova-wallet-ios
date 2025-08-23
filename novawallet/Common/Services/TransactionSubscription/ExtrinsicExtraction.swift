import Foundation
import SubstrateSdk

enum ExtrinsicExtraction {
    static func getSender(from extrinsic: Extrinsic, codingFactory: RuntimeCoderFactoryProtocol) -> AccountId? {
        try? extrinsic.getSignedExtrinsic()?.signature.address.map(
            to: MultiAddress.self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ).accountId
    }

    static func getTypedCall<T: Decodable>(
        from json: JSON,
        context: RuntimeJsonContext?
    ) throws -> RuntimeCall<T> {
        try json.map(to: RuntimeCall<T>.self, with: context?.toRawContext())
    }

    static func getCall(from json: JSON, context: RuntimeJsonContext?) throws -> RuntimeCall<JSON> {
        try json.map(to: RuntimeCall<JSON>.self, with: context?.toRawContext())
    }

    static func getCallArgs<T: Decodable>(from json: JSON, context: RuntimeJsonContext?) throws -> T {
        try json.map(to: T.self, with: context?.toRawContext())
    }

    static func getEventParams<T: Decodable>(from event: Event, context: RuntimeJsonContext?) throws -> T {
        try event.params.map(to: T.self, with: context?.toRawContext())
    }
}
