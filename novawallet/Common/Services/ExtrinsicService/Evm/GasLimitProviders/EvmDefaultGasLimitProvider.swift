import Foundation
import BigInt
import RobinHood

final class EvmDefaultGasLimitProvider {
    let operationFactory: EthereumOperationFactoryProtocol

    init(operationFactory: EthereumOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension EvmDefaultGasLimitProvider: EvmGasLimitProviderProtocol {
    func getGasLimitWrapper(for transaction: EthereumTransaction) -> CompoundOperationWrapper<BigUInt> {
        let fetchOperation = operationFactory.createGasLimitOperation(for: transaction)

        let mapOperation = ClosureOperation<BigUInt> {
            try fetchOperation.extractNoCancellableResultData().wrappedValue
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
