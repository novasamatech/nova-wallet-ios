protocol PriceHistoryCalculatorFactoryProtocol {
    func createPriceCalculator(for priceId: String?) -> TokenPriceCalculatorProtocol?
    func replace(history: PriceHistory, priceId: AssetModel.PriceId)
}

final class PriceHistoryCalculatorFactory: PriceHistoryCalculatorFactoryProtocol {
    private var priceHistory: [AssetModel.PriceId: PriceHistory?] = [:]

    func replace(history: PriceHistory, priceId: AssetModel.PriceId) {
        priceHistory[priceId] = history
    }

    func createPriceCalculator(for priceId: String?) -> TokenPriceCalculatorProtocol? {
        guard let priceId = priceId,
              let priceHistory = priceHistory[priceId],
              let history = priceHistory else {
            return nil
        }
        return TokenPriceCalculator(history: history)
    }
}
