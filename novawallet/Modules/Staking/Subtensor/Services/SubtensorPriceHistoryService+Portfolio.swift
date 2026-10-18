import Foundation
import Operation_iOS

extension SubtensorPriceHistoryService {
    func createPortfolioHistoryWrapper(
        accountSubject: AccountAddress,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPortfolioPriceHistories> {
        let historyWrapper = apiOperationFactory.createPortfolioHistoryWrapper(
            accountSubject: accountSubject,
            period: period.portfolioHistoryPeriod
        )

        let taoOperation = currency.id == Currency.usd.id ? nil : coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: currency,
            period: period.sourceCoingeckoPeriod
        )

        let historiesOperation = ClosureOperation<SubtensorPortfolioPriceHistories> {
            SubtensorPortfolioPriceHistories(
                period: period,
                portfolio: try historyWrapper.targetOperation.extractNoCancellableResultData().value,
                taoFiat: try taoOperation?.extractNoCancellableResultData()
            )
        }

        historiesOperation.addDependency(historyWrapper.targetOperation)
        taoOperation.map { historiesOperation.addDependency($0) }

        let dependencies = historyWrapper.allOperations + (taoOperation.map { [$0] } ?? [])

        return CompoundOperationWrapper(targetOperation: historiesOperation, dependencies: dependencies)
    }
}
