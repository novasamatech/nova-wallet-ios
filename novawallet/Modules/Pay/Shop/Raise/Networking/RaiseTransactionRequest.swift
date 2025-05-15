import Foundation

struct RaiseTransactionCreateAttributes: Encodable {
    struct Card: Encodable {
        enum CodingKeys: String, CodingKey {
            case brandId = "brand_id"
            case value
            case quantity
        }

        let brandId: String
        let value: Int
        let quantity: Int
    }

    struct Customer: Encodable {
        enum CodingKeys: String, CodingKey {
            case identifier = "id"
        }

        let identifier: String
    }

    struct PaymentMethodCrypto: Encodable {
        let asset: String
        let network: String
    }

    struct PaymentMethod: Encodable {
        let crypto: PaymentMethodCrypto
    }

    enum CodingKeys: String, CodingKey {
        case type
        case cards
        case customer
        case clientOrderId = "client_order_id"
        case paymentMethod = "payment_method"
    }

    let type: String
    let cards: [Card]
    let customer: Customer
    let clientOrderId: String
    let paymentMethod: PaymentMethod
}

struct RaiseTransactionUpdateAttributes: Encodable {
    let cards: [RaiseTransactionCreateAttributes.Card]
}
