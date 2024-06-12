import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmLegacyGasPriceProvider {
    let operationFactory: EthereumOperationFactoryProtocol

    init(operationFactory: EthereumOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension EvmLegacyGasPriceProvider: EvmGasPriceProviderProtocol {
    func getGasPriceWrapper() -> CompoundOperationWrapper<BigUInt> {
        let fetchOperation = operationFactory.createGasPriceOperation()

        let mapOperation = ClosureOperation<BigUInt> {
            try fetchOperation.extractNoCancellableResultData().wrappedValue
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
