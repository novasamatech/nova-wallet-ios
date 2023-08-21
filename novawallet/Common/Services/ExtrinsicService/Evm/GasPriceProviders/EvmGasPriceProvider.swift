import Foundation
import RobinHood
import BigInt
import SubstrateSdk

protocol EvmGasPriceProviderProtocol {
    func getGasPriceWrapper() -> CompoundOperationWrapper<BigUInt>
}

enum EvmGasPriceProviderError: Error {
    case unsupported
}
