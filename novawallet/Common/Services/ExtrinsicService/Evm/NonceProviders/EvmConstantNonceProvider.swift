import Foundation
import BigInt
import RobinHood

final class EvmConstantNonceProvider {
    let value: BigUInt

    init(value: BigUInt) {
        self.value = value
    }
}

extension EvmConstantNonceProvider: EvmNonceProviderProtocol {
    func getNonceWrapper(
        for _: Data,
        block _: EthereumBlock
    ) -> CompoundOperationWrapper<BigUInt> {
        CompoundOperationWrapper.createWithResult(value)
    }
}
