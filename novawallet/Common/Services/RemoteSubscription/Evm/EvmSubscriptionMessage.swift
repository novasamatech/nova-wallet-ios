import Foundation

enum EvmSubscriptionMessage {
    static let method = "eth_subscribe"

    struct LogsMessage: Encodable {
        static let type = "logs"

        let logs: Logs

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(Self.type)
            try container.encode(logs)
        }
    }

    struct Logs: Encodable {
        let address: [AccountAddress]
        let topics: [String]
    }
}
