import Foundation
import BigInt
import Core

enum EvmSubscriptionMessage {
    static let subscribeMethod = "eth_subscribe"
    static let unsubscribeMethod = "eth_unsubscribe"
}

extension EvmSubscriptionMessage {
    struct ERC20Transfer {
        let incomingFilter: LogsParams
        let outgoingFilter: LogsParams
    }

    struct LogsParams: Encodable {
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

extension EvmSubscriptionMessage {
    struct NewHeadsParams: Encodable {
        static let type = "newHeads"

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.type)
        }
    }

    struct NewHeadsUpdate: Decodable {
        enum CodingKeys: String, CodingKey {
            case blockNumber = "number"
        }

        let blockNumber: BigUInt

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            blockNumber = try container.decodeHex(BigUInt.self, forKey: .blockNumber)
        }
    }
}
