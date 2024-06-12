import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

protocol EvmGasLimitProviderProtocol {
    func getGasLimitWrapper(for transaction: EthereumTransaction) -> CompoundOperationWrapper<BigUInt>
}
