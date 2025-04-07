import Foundation

struct TransakEvent<EventData: Decodable>: Decodable {
    let eventId: TransakEventId
    let data: EventData

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case data
    }
}

struct TransakTransferEventData: Decodable {
    let status: TransakEventStatus
    let cryptoAmount: Decimal
    let cryptoPaymentData: TransakPaymentAddress
}

enum TransakEventId: String, Decodable {
    case orderCreated = "TRANSAK_ORDER_CREATED"
}

enum TransakEventStatus: String, Decodable {
    case awaitingPayment = "AWAITING_PAYMENT_FROM_USER"
}

struct TransakPaymentAddress: Decodable {
    let paymentAddress: String
    let address: String
}
