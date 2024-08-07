import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

protocol EvmGasPriceProviderProtocol {
    func getGasPriceWrapper() -> CompoundOperationWrapper<BigUInt>
}

enum EvmGasPriceProviderError: Error {
    case unsupported
}
