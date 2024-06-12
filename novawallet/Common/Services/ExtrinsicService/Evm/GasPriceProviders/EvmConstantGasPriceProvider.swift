import Foundation
import Operation_iOS
import BigInt

final class EvmConstantGasPriceProvider {
    let value: BigUInt

    init(value: BigUInt) {
        self.value = value
    }
}

extension EvmConstantGasPriceProvider: EvmGasPriceProviderProtocol {
    func getGasPriceWrapper() -> CompoundOperationWrapper<BigUInt> {
        CompoundOperationWrapper.createWithResult(value)
    }
}
