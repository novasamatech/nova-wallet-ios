import Foundation

protocol CrowdloansCalculatorProtocol {
    func calculateTotal(
        precision: Int16?,
        contributions: CrowdloanContributionDict,
        externalContributions: [ExternalContribution]?
    ) -> Decimal?
}

final class CrowdloansCalculator: CrowdloansCalculatorProtocol {
    func calculateTotal(
        precision: Int16?,
        contributions: CrowdloanContributionDict,
        externalContributions: [ExternalContribution]?
    ) -> Decimal? {
        guard let precision = precision else {
            return nil
        }

        let balance = contributions.values.reduce(0) { $0 + $1.balance }
        let externalContributionsBalance = externalContributions?.reduce(0) { $0 + $1.amount } ?? 0
        let total = balance + externalContributionsBalance

        return Decimal.fromSubstrateAmount(total, precision: precision)
    }
}
