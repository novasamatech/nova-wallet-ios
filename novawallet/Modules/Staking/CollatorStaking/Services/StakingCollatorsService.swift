import Foundation
import Operation_iOS

protocol StakingCollatorsServiceProtocol {
    func fetchStakableCollatorsWrapper() -> CompoundOperationWrapper<[AccountId]>
}
