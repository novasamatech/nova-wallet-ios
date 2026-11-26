import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

protocol EvmGasPriceProviderProtocol {
    func getGasPriceWrapper() -> CompoundOperationWrapper<BigUInt>
}

protocol EvmEip1559PriceProviderProtocol {
    func getEip1559PriceWrapper() -> CompoundOperationWrapper<EvmEip1559Fee>
}

enum EvmGasPriceProviderError: Error {
    case unsupported
}
