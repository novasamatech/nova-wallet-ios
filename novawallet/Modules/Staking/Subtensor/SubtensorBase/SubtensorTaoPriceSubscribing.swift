import Foundation
import Operation_iOS

protocol SubtensorTaoPriceSubscribing: AnyObject, PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    var chainAsset: ChainAsset { get }
    var priceProvider: StreamableProvider<PriceData>? { get set }
    var logger: LoggerProtocol { get }

    func deliverTaoPrice(_ price: PriceData?)
}

extension SubtensorTaoPriceSubscribing {
    func subscribeTaoPrice(currency: Currency) {
        guard let priceId = chainAsset.asset.priceId else {
            deliverTaoPrice(nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: currency)
    }

    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        guard chainAsset.asset.priceId == priceId else {
            return
        }

        switch result {
        case let .success(price):
            deliverTaoPrice(price)
        case let .failure(error):
            logger.error("Subtensor TAO price unavailable: \(error)")
            deliverTaoPrice(nil)
        }
    }
}
