import Foundation
import RobinHood
import BigInt
import SubstrateSdk

protocol EvmGasLimitProviderProtocol {
    func getGasLimitWrapper(for transaction: EthereumTransaction) -> CompoundOperationWrapper<BigUInt>
}
