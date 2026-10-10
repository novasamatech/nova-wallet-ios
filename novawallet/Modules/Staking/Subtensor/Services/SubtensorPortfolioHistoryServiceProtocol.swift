import Foundation
import Operation_iOS

protocol SubtensorPortfolioHistoryServiceProtocol: AnyObject {
    func createHistoryWrapper(
        for accountSubject: AccountAddress,
        period: SubtensorPricePeriod
    ) -> CompoundOperationWrapper<SubtensorPortfolioStakeHistory>
}
