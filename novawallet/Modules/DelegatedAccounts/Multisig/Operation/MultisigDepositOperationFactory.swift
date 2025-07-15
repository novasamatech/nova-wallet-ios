import Foundation
import Operation_iOS

protocol MultisigDepositOperationFactoryProtocol {
    func depositWrapper(
        for chainId: ChainModel.Id,
        threshold: MultisigPallet.Threshold
    ) -> CompoundOperationWrapper<Balance>
}

final class MultisigDepositOperationFactory {
    let chainRegitry: ChainRegistryProtocol

    init(chainRegitry: ChainRegistryProtocol) {
        self.chainRegitry = chainRegitry
    }
}

extension MultisigDepositOperationFactory: MultisigDepositOperationFactoryProtocol {
    func depositWrapper(
        for chainId: ChainModel.Id,
        threshold: MultisigPallet.Threshold
    ) -> CompoundOperationWrapper<Balance> {
        do {
            let runtimeProvider = try chainRegitry.getRuntimeProviderOrError(for: chainId)

            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let depositBaseOperation = PrimitiveConstantOperation<Balance>(path: MultisigPallet.depositBase)
            let depositFactorOperation = PrimitiveConstantOperation<Balance>(path: MultisigPallet.depositFactor)

            let calculateOperation = ClosureOperation<Balance> {
                let base = try depositBaseOperation.extractNoCancellableResultData()
                let factor = try depositFactorOperation.extractNoCancellableResultData()

                return base + factor * Balance(threshold)
            }

            [depositBaseOperation, depositFactorOperation].forEach { operation in
                operation.addDependency(coderFactoryOperation)

                operation.configurationBlock = {
                    do {
                        operation.codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
                    } catch {
                        operation.result = .failure(error)
                    }
                }

                calculateOperation.addDependency(operation)
            }

            return CompoundOperationWrapper(
                targetOperation: calculateOperation,
                dependencies: [coderFactoryOperation, depositBaseOperation, depositFactorOperation]
            )
        } catch {
            return .createWithError(error)
        }
    }
}
