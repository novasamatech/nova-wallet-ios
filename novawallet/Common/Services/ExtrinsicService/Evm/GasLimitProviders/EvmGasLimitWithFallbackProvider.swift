import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

final class EvmGasLimitFallbackProvider {
    let mainProvider: EvmGasLimitProviderProtocol
    let fallbackProvider: EvmGasLimitProviderProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        mainProvider: EvmGasLimitProviderProtocol,
        fallbackProvider: EvmGasLimitProviderProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.mainProvider = mainProvider
        self.fallbackProvider = fallbackProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createWrapper(
        for transaction: EthereumTransaction,
        mainProvider: EvmGasLimitProviderProtocol,
        fallbackProvider: EvmGasLimitProviderProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<BigUInt> {
        let mainGasLimitWrapper = mainProvider.getGasLimitWrapper(for: transaction)

        let fallbackOperation: BaseOperation<[BigUInt]> = OperationCombiningService(
            operationManager: operationManager
        ) {
            do {
                let limit = try mainGasLimitWrapper.targetOperation.extractNoCancellableResultData()

                let resultWrapper = CompoundOperationWrapper.createWithResult(limit)
                return [resultWrapper]
            } catch is JSONRPCError {
                logger.warning("Using fallback for gas limit due to error")

                let resultWrapper = fallbackProvider.getGasLimitWrapper(for: transaction)
                return [resultWrapper]
            }
        }
        .longrunOperation()

        fallbackOperation.addDependency(mainGasLimitWrapper.targetOperation)

        let mapOperation = ClosureOperation<BigUInt> {
            let optLimit = try fallbackOperation.extractNoCancellableResultData().first

            guard let limit = optLimit else {
                throw CommonError.dataCorruption
            }

            return limit
        }

        mapOperation.addDependency(fallbackOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: mainGasLimitWrapper.allOperations + [fallbackOperation]
        )
    }
}

extension EvmGasLimitFallbackProvider: EvmGasLimitProviderProtocol {
    func getGasLimitWrapper(for transaction: EthereumTransaction) -> CompoundOperationWrapper<BigUInt> {
        createWrapper(
            for: transaction,
            mainProvider: mainProvider,
            fallbackProvider: fallbackProvider,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )
    }
}
