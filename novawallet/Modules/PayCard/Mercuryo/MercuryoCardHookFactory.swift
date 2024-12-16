import Foundation

enum MercuryoCardApi {
    static let widgetUrl = URL(string: "https://exchange.mercuryo.io/")!
    static let widgetId = "4ce98182-ed76-4933-ba1b-b85e4a51d75a" // TODO: Change for production
    static let theme = "nova"
    static let type = "sell"
    static let fiatCurrency = "EUR"
    static let fixFiatCurrency = "true"
    static let fixPaymentMethod = "true"
    static let paymentMethod = "fiat_card_open"
    static let showSpendCardDetails = "true"
    static let hideRefundAddress = "true"
    static let cardsEndpoint = "https://api.mercuryo.io/v1.6/cards"
    static let pendingTimeout: TimeInterval = 5.secondsFromMinutes
}

final class MercuryoCardHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension MercuryoCardHookFactory: PayCardHookFactoryProtocol {
    func createHooks(for delegate: PayCardHookDelegate) -> [PayCardHook] {
        let responseHook = createCardsResponseInterceptingHook(for: delegate)
        let widgetHooks = createWidgetHooks(for: delegate)

        return widgetHooks + [responseHook]
    }
}
