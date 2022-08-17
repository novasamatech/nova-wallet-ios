import Foundation

protocol CrowdloansCalculatorProtocol {
    func calculateTotal(
        chain: ChainModel,
        contributions: CrowdloanContributionDict,
        externalContributions: [ExternalContribution]?
    ) -> Decimal?
}

final class CrowdloansCalculator: CrowdloansCalculatorProtocol {
    func calculateTotal(
        chain: ChainModel,
        contributions: CrowdloanContributionDict,
        externalContributions: [ExternalContribution]?
    ) -> Decimal? {
        let balance = contributions.values.reduce(0) { $0 + $1.balance }
        let externalContributionsBalance = externalContributions?.reduce(0) { $0 + $1.amount } ?? 0
        let total = balance + externalContributionsBalance
        guard let precision = chain.utilityAsset()?.precision else {
            return nil
        }
        return Decimal.fromSubstrateAmount(total, precision: Int16(precision))
    }
}

