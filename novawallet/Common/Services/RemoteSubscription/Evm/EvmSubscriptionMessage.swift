import Foundation

enum EvmSubscriptionMessage {
    static let subscribeMethod = "eth_subscribe"
    static let unsubscribeMethod = "eth_unsubscribe"

    struct ERC20Transfer {
        let incomingFilter: Params
        let outgoingFilter: Params
    }

    struct Params: Encodable {
        static let type = "logs"

        let logs: LogsFilter

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(Self.type)
            try container.encode(logs)
        }
    }

    enum Topic: Encodable {
        case anyOf([Data])
        case single(Data)
        case anyValue

        func encode(to encoder: Encoder) throws {
            var singleValueContainer = encoder.singleValueContainer()

            switch self {
            case let .anyOf(values):
                let hexValues = values.map { $0.toHex(includePrefix: true) }
                try singleValueContainer.encode(hexValues)
            case let .single(value):
                let hexValue = value.toHex(includePrefix: true)
                try singleValueContainer.encode(hexValue)
            case .anyValue:
                try singleValueContainer.encodeNil()
            }
        }
    }

    struct LogsFilter: Encodable {
        let address: [AccountAddress]
        let topics: [Topic]
    }
}
