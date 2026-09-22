import Foundation
import SubstrateSdk

extension Proxy {
    static var executedEventPath: EventCodingPath {
        EventCodingPath(moduleName: Proxy.name, eventName: "ProxyExecuted")
    }

    struct ExecutedEvent: Decodable {
        let result: Substrate.Result<JSON, JSON>

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            result = try unkeyedContainer.decode(Substrate.Result<JSON, JSON>.self)
        }
    }
}
