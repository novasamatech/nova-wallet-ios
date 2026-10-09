import Foundation
import Operation_iOS

struct SubtensorPriceHistoryEntry {
    let result: SubtensorPriceHistoryResult
    let expiresAt: Date
}

protocol SubtensorPriceHistoryServiceProtocol: AnyObject {
    func createHistoryEntryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryEntry>

    func createWeeklyChangesWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]>
}

extension SubtensorPriceHistoryServiceProtocol {
    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryResult> {
        let entryWrapper = createHistoryEntryWrapper(for: subnet, period: period, currency: currency)

        let resultOperation = ClosureOperation<SubtensorPriceHistoryResult> {
            try entryWrapper.targetOperation.extractNoCancellableResultData().result
        }

        resultOperation.addDependency(entryWrapper.targetOperation)

        return entryWrapper.insertingTail(operation: resultOperation)
    }
}
