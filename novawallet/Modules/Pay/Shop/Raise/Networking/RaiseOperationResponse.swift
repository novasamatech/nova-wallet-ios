import Foundation

struct RaiseBrandAttributes: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case terms
        case commissionRate = "commission_rate"
        case iconUrl = "icon_url"
        case transactionConfig = "transaction_config"
    }

    struct TransactionVariableLoad: Decodable, Equatable {
        enum CodingKeys: String, CodingKey {
            case increment
            case minimumAmount = "minimum_amount"
            case maximumAmount = "maximum_amount"
        }

        let increment: Int
        let minimumAmount: Int
        let maximumAmount: Int
    }

    struct TransactionFixedLoad: Decodable, Equatable {
        let amounts: [Int]
    }

    enum TransactionConfig: Decodable, Equatable {
        enum CodingKeys: String, CodingKey {
            case variableLoad = "variable_load"
            case fixedLoad = "fixed_load"
        }

        case variableLoad(TransactionVariableLoad)
        case fixedLoad(TransactionFixedLoad)

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            var allKeys = ArraySlice(container.allKeys)
            guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                // TransactionConfig should have either variableLoad or fixedLoad, not both
                throw DecodingError.typeMismatch(
                    TransactionConfig.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid number of keys found, expected one, got \(allKeys.count)."
                    )
                )
            }

            switch onlyKey {
            case .variableLoad:
                let load = try container.decode(TransactionVariableLoad.self, forKey: onlyKey)
                self = .variableLoad(load)
            case .fixedLoad:
                let load = try container.decode(TransactionFixedLoad.self, forKey: onlyKey)
                self = .fixedLoad(load)
            }
        }
    }

    let name: String
    let description: String?
    let terms: String?
    let commissionRate: Double
    let iconUrl: String?
    let transactionConfig: TransactionConfig

    var comissionInPercentFraction: Double {
        commissionRate / 10000
    }
}

struct RaiseResource<I> {
    let identifier: String
    let attributes: I
}

struct RaiseListResult<I> {
    let items: [RaiseResource<I>]
    let total: Int
}

typealias RaiseBrandRemote = RaiseResource<RaiseBrandAttributes>

struct RaiseCryptoAssetAttributes: Decodable {
    enum CodingKeys: String, CodingKey {
        case network
        case name
        case icon = "icon_url"
    }

    let network: String
    let name: String
    let icon: String?
}

typealias RaiseCryptoAssetRemote = RaiseResource<RaiseCryptoAssetAttributes>

struct RaiseTransactionAttributes: Decodable {
    struct PaymentMethodCrypto: Decodable {
        enum CodingKeys: String, CodingKey {
            case paymentAddress = "payment_address"
            case paymentTotal = "payment_total"
            case paymentExpiresAt = "payment_expires_at"
        }

        let paymentAddress: String
        let paymentTotal: Decimal
        let paymentExpiresAt: Int?
    }

    struct PaymentMethod: Decodable {
        let crypto: PaymentMethodCrypto
    }

    struct CardValue: Decodable {
        let value: String?
        let raw: String
    }

    struct Card: Decodable {
        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case number
            case pin = "csc"
            case url
            case balance
            case expiresAt = "expires_at"
            case currency
        }

        let identifier: String
        let number: CardValue?
        let pin: CardValue?
        let url: CardValue?
        let balance: RaiseBalance
        @ISO8601Codable var expiresAt: Date?
        let currency: String
    }

    enum State: Decodable {
        case pending
        case completed
        case failed
        case cancelled

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            let value = try container.decode(String.self)

            switch value {
            case "PENDING":
                self = .pending
            case "COMPLETED":
                self = .completed
            case "FAILED":
                self = .failed
            case "CANCELED":
                self = .cancelled
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid value"
                    )
                )
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case state
        case paymentMethod = "payment_method"
        case cards
    }

    let state: State
    let paymentMethod: PaymentMethod?
    let cards: [Card]?

    var isSuccess: Bool {
        switch state {
        case .completed:
            true
        case .pending,
             .cancelled,
             .failed:
            false
        }
    }
}

struct RaiseCryptoQuoteAttributes: Decodable {
    enum CodingKeys: String, CodingKey {
        case fromCurrency = "from_currency"
        case toCurrency = "to_currency"
        case rate
    }

    let fromCurrency: String
    let toCurrency: String
    let rate: Decimal
}
