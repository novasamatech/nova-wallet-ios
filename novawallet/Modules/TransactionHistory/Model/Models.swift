import SoraUI

public typealias PaginationContext1 = [String: String]
public struct Pagination1: Codable, Equatable {
    public let context: PaginationContext1?
    public let count: Int

    public init(count: Int, context: [String: String]? = nil) {
        self.count = count
        self.context = context
    }
}

public enum AssetTransactionStatus1: String, Codable {
    case pending = "PENDING"
    case commited = "COMMITTED"
    case rejected = "REJECTED"
}

public struct AssetTransactionData1: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case transactionId
        case status
        case assetId
        case peerId
        case peerName
        case peerFirstName
        case peerLastName
        case details
        case amount
        case fees
        case timestamp
        case type
        case reason
        case context
    }

    public let transactionId: String
    public let status: AssetTransactionStatus1
    public let assetId: String
    public let peerId: String
    public let peerFirstName: String?
    public let peerLastName: String?
    public let peerName: String?
    public let details: String
    public let amount: AmountDecimal1
    public let fees: [AssetTransactionFee1]
    public let timestamp: Int64
    public let type: String
    public let reason: String?
    public let context: [String: String]?

    public init(
        transactionId: String,
        status: AssetTransactionStatus1,
        assetId: String,
        peerId: String,
        peerFirstName: String?,
        peerLastName: String?,
        peerName: String?,
        details: String,
        amount: AmountDecimal1,
        fees: [AssetTransactionFee1],
        timestamp: Int64,
        type: String,
        reason: String?,
        context: [String: String]?
    ) {
        self.transactionId = transactionId
        self.status = status
        self.assetId = assetId
        self.peerId = peerId
        self.peerFirstName = peerFirstName
        self.peerLastName = peerLastName
        self.peerName = peerName
        self.details = details
        self.amount = amount
        self.fees = fees
        self.timestamp = timestamp
        self.type = type
        self.reason = reason
        self.context = context
    }
}

public struct AssetTransactionPageData1: Codable, Equatable {
    public let transactions: [AssetTransactionData1]
    public let context: PaginationContext1?

    public init(
        transactions: [AssetTransactionData1],
        context: PaginationContext1? = nil
    ) {
        self.transactions = transactions
        self.context = context
    }
}

public enum AmountDecimalError1: Error {
    case invalidStringValue
}

public struct AmountDecimal1: Codable, Equatable {
    public let decimalValue: Decimal

    public var stringValue: String {
        (decimalValue as NSNumber).stringValue
    }

    public init(value: Decimal) {
        decimalValue = value
    }

    public init?(string: String) {
        guard let value = Decimal(string: string) else {
            return nil
        }

        self.init(value: value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let stringValue = try container.decode(String.self)

        guard let value = Decimal(string: stringValue) else {
            throw AmountDecimalError1.invalidStringValue
        }

        decimalValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

public struct AssetTransactionFee1: Codable, Equatable {
    public let identifier: String
    public let assetId: String
    public let amount: AmountDecimal1
    public let context: [String: String]?

    public init(identifier: String, assetId: String, amount: AmountDecimal1, context: [String: String]?) {
        self.identifier = identifier
        self.assetId = assetId
        self.amount = amount
        self.context = context
    }
}
