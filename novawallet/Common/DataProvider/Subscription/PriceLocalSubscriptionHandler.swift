import Foundation

protocol PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId: AssetModel.PriceId
    )

    func handlePriceHistory(
        result: Result<PriceHistory?, Error>,
        priceId: AssetModel.PriceId
    )
}

extension PriceLocalSubscriptionHandler {
    func handlePrice(
        result _: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {}

    func handlePriceHistory(
        result _: Result<PriceHistory?, Error>,
        priceId _: AssetModel.PriceId
    ) {}
}
