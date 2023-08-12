import Foundation
import RobinHood
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
            let gasPriceString = try fetchOperation.extractNoCancellableResultData()

            guard let gasPrice = BigUInt.fromHexString(gasPriceString) else {
                throw CommonError.dataCorruption
            }

            return gasPrice
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
