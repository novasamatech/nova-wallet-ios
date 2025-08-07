import Foundation
import Operation_iOS

protocol StakingDurationOperationFactoryProtocol {
    func createDurationOperation() -> CompoundOperationWrapper<StakingDuration>
}
