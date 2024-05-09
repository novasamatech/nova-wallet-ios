import Foundation
import Operation_iOS
import BigInt

final class EvmDefaultNonceProvider {
    let operationFactory: EthereumOperationFactoryProtocol

    init(operationFactory: EthereumOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension EvmDefaultNonceProvider: EvmNonceProviderProtocol {
    func getNonceWrapper(
        for accountAddress: Data,
        block: EthereumBlock
    ) -> CompoundOperationWrapper<BigUInt> {
        let fetchOperation = operationFactory.createTransactionsCountOperation(
            for: accountAddress,
            block: block
        )

        let mapOperation = ClosureOperation<BigUInt> {
            try fetchOperation.extractNoCancellableResultData().wrappedValue
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
