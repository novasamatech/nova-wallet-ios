import Foundation
import Operation_iOS

protocol SubtensorPriceHistoryOperationFactoryProtocol: AnyObject {
    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency,
        registrationDate: Date?
    ) -> CompoundOperationWrapper<SubtensorPriceHistory?>

    func createWeeklyChangesWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]>

    func createPortfolioHistoryWrapper(
        accountSubject: AccountAddress,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPortfolioPriceHistories>
}
