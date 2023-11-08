protocol CalculatorFactoryProtocol {
    func createPriceCalculator(for priceId: String?) -> TokenPriceCalculatorProtocol?
}

final class CalculatorFactory: CalculatorFactoryProtocol {
    var priceHistory: [AssetModel.PriceId: PriceHistory?] = [:]

    func createPriceCalculator(for priceId: String?) -> TokenPriceCalculatorProtocol? {
        guard let priceId = priceId,
              let priceHistory = priceHistory[priceId],
              let history = priceHistory else {
            return nil
        }
        return TokenPriceCalculator(history: history)
    }
}
