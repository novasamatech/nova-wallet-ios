import Foundation
import RobinHood
import BigInt

final class EvmConstantGasLimitProvider {
    let value: BigUInt

    init(value: BigUInt) {
        self.value = value
    }
}

extension EvmConstantGasLimitProvider: EvmGasLimitProviderProtocol {
    func getGasLimitWrapper(for _: EthereumTransaction) -> CompoundOperationWrapper<BigUInt> {
        CompoundOperationWrapper.createWithResult(value)
    }
}
