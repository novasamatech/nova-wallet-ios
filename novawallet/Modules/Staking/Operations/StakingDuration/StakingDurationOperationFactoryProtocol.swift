import Foundation
import RobinHood

protocol StakingDurationOperationFactoryProtocol {
    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<StakingDuration>
}
