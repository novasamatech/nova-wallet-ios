import Foundation

struct MercuryoCardParams {
    let chainAsset: ChainAsset
    let refundAddress: AccountAddress
}

enum MercuryoApi {
    static let widgetUrl = URL(string: "https://exchange.mercuryo.io/")!
    static let widgetId = "4ce98182-ed76-4933-ba1b-b85e4a51d75a"
    static let theme = "nova"
    static let type = "sell"
    static let fixFiatCurrency = "true"
    static let showSpendCardDetails = "true"
    static let hideRefundAddress = "true"
    static let cardsEndpoint = "https://api.mercuryo.io/v1.6/cards"
    static let topUpEndpoint = "https://api.mercuryo.io/v1.6/widget/sell-request"
    static let buyEndpoint = "https://api.mercuryo.io/v1.6/widget/buy"
    static let pendingTimeout: TimeInterval = 5.secondsFromMinutes
}

final class MercuryoCardHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension MercuryoCardHookFactory: PayCardHookFactoryProtocol {
    func createHooks(
        using params: MercuryoCardParams,
        for delegate: PayCardHookDelegate
    ) -> [PayCardHook] {
        let responseHook = createResponseInterceptingHook(
            using: params,
            for: delegate
        )
        let widgetHook = createWidgetHook(for: delegate)

        return [widgetHook, responseHook]
    }
}
