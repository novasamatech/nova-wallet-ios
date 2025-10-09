import Foundation
import Operation_iOS

protocol PayoutRewardsServiceProtocol {
    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<Staking.PayoutsInfo>
}

enum PayoutRewardsServiceError: Error {
    case unknown
}
