import Foundation
import Operation_iOS

struct SubtensorMonthlyPriceMetrics: Equatable {
    let changeInTao: Decimal?
    let meanTaoPerAlpha: Decimal?
}

protocol SubtensorPriceHistoryServiceProtocol: AnyObject {
    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryResult>

    func createWeeklyChangesWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: Decimal]>

    func createMonthlyMetricsWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorMonthlyPriceMetrics]>
}
