import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmMaxPriorityGasPriceProvider {
    let operationFactory: EthereumOperationFactoryProtocol

    init(operationFactory: EthereumOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension EvmMaxPriorityGasPriceProvider: EvmGasPriceProviderProtocol {
    func getGasPriceWrapper() -> CompoundOperationWrapper<BigUInt> {
        let lastBlockOperation = operationFactory.createReducedBlockOperation(for: .latest)
        let maxPriorityOperation = operationFactory.createMaxPriorityPerGasOperation()

        let mapOperation = ClosureOperation<BigUInt> {
            guard let baseFee = try lastBlockOperation.extractNoCancellableResultData().baseFeePerGas else {
                throw EvmGasPriceProviderError.unsupported
            }

            let maxPriorityFee = try maxPriorityOperation.extractNoCancellableResultData().wrappedValue

            return baseFee + maxPriorityFee
        }

        mapOperation.addDependency(lastBlockOperation)
        mapOperation.addDependency(maxPriorityOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [lastBlockOperation, maxPriorityOperation]
        )
    }
}
