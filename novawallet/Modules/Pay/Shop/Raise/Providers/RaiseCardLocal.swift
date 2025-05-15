import Foundation
import Operation_iOS

struct RaiseCardLocal: Equatable {
    let identifier: String
    let brandId: String
    let brandAttributes: RaiseBrandAttributes?
    let number: String?
    let formattedNumber: String?
    let pin: String?
    let formattedPin: String?
    let viewCardUrl: String?
    let expiresAt: Date?
    let balance: RaiseBalance
    let currency: String
    let sortOrder: Int
}

extension RaiseCardLocal {
    init(
        fromRemote card: RaiseTransactionAttributes.Card,
        brand: RaiseBrandRemote,
        sortOrder: Int
    ) {
        identifier = card.identifier
        brandId = brand.identifier
        brandAttributes = brand.attributes
        number = card.number?.raw
        formattedNumber = card.number?.value
        expiresAt = card.expiresAt
        pin = card.pin?.raw
        formattedPin = card.pin?.value
        viewCardUrl = card.url?.raw
        balance = card.balance
        currency = card.currency
        self.sortOrder = sortOrder
    }

    init(
        fromRemote card: RaiseResponseContent<RaiseCardAttributes>,
        brand: RaiseBrandAttributes?,
        sortOrder: Int
    ) {
        identifier = card.identifier
        brandId = card.attributes.brandId
        brandAttributes = brand
        number = card.attributes.number?.raw
        formattedNumber = card.attributes.number?.value
        expiresAt = card.attributes.expiresAt
        pin = card.attributes.pin?.raw
        formattedPin = card.attributes.pin?.value
        viewCardUrl = card.attributes.url?.raw
        balance = card.attributes.balance
        currency = card.attributes.currency
        self.sortOrder = sortOrder
    }

    var brandName: String? {
        brandAttributes?.name
    }

    var brandUrl: String? {
        brandAttributes?.iconUrl
    }

    var brandCashback: Double? {
        brandAttributes?.comissionInPercentFraction
    }
}

extension RaiseCardLocal: Operation_iOS.Identifiable {}

extension Sequence<RaiseCardLocal> {
    var totalBalance: Balance {
        reduce(Balance(0)) { $0 + Balance($1.balance) }
    }
}

extension RaiseBrandRemote {
    init?(card: RaiseCardLocal) {
        guard let brandAttributes = card.brandAttributes else {
            return nil
        }

        identifier = card.brandId
        attributes = brandAttributes
    }
}

extension RaiseCardLocal {
    var isDebit: Bool {
        if number != nil, pin != nil {
            true
        } else if viewCardUrl != nil {
            false
        } else {
            true
        }
    }
}
