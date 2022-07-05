import Foundation
import SubstrateSdk
import RobinHood

protocol EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper(
        for connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<EraCountdown>
}

enum EraCountdownOperationFactoryError: Error {
    case noData
}
