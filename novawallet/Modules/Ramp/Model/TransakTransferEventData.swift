import Foundation

enum TransakEvent: Decodable {
    case orderCreated(data: TransakTransferEventData)
    case widgetClose(data: Bool)

    private enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventIdString = try container.decode(TransakEventId.self, forKey: .eventId)

        switch eventIdString {
        case .orderCreated:
            let eventData = try container.decode(TransakTransferEventData.self, forKey: .data)
            self = .orderCreated(data: eventData)
        case .widgetClose:
            let eventData = try container.decode(Bool.self, forKey: .data)
            self = .widgetClose(data: eventData)
        }
    }
}

enum TransakEventId: String, Decodable {
    case orderCreated = "TRANSAK_ORDER_CREATED"
    case widgetClose = "TRANSAK_WIDGET_CLOSE"
}

struct TransakTransferEventData: Decodable {
    let status: TransakEventStatus
    let cryptoAmount: Decimal
    let cryptoPaymentData: TransakPaymentAddress
}

enum TransakEventStatus: String, Decodable {
    case awaitingPayment = "AWAITING_PAYMENT_FROM_USER"
}

struct TransakPaymentAddress: Decodable {
    let paymentAddress: String
    let address: String
}
