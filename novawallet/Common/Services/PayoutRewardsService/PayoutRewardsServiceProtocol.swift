import Foundation
import Operation_iOS

protocol PayoutRewardsServiceProtocol {
    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<PayoutsInfo>
}

enum PayoutRewardsServiceError: Error {
    case unknown
}
