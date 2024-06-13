import Foundation
import SubstrateSdk
import Operation_iOS

protocol EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper(
        for connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<EraCountdown>
}

enum EraCountdownOperationFactoryError: Error {
    case noData
}
