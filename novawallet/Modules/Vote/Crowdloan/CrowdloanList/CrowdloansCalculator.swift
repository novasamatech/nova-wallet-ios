import Foundation

protocol CrowdloansCalculatorProtocol {
    func calculateTotal(
        contributions: [CrowdloanContribution],
        assetInfo: ChainAssetDisplayInfo
    ) -> Decimal
}

final class CrowdloansCalculator: CrowdloansCalculatorProtocol {
    func calculateTotal(
        contributions: [CrowdloanContribution],
        assetInfo: ChainAssetDisplayInfo
    ) -> Decimal {
        let balance = contributions.reduce(0) { $0 + $1.amount }

        return balance.decimal(assetInfo: assetInfo)
    }
}
