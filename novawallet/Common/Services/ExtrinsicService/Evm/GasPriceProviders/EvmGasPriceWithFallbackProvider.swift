import Foundation
import SubstrateSdk
import RobinHood
import BigInt

final class EvmGasPriceWithFallbackProvider {
    let mainPriceProvider: EvmGasPriceProviderProtocol
    let fallbackPriceProvider: EvmGasPriceProviderProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        mainPriceProvider: EvmGasPriceProviderProtocol,
        fallbackPriceProvider: EvmGasPriceProviderProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.mainPriceProvider = mainPriceProvider
        self.fallbackPriceProvider = fallbackPriceProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createWrapper(
        for mainProvider: EvmGasPriceProviderProtocol,
        fallbackProvider: EvmGasPriceProviderProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<BigUInt> {
        let mainGasPriceWrapper = mainProvider.getGasPriceWrapper()

        let fallbackOperation: BaseOperation<[BigUInt]> = OperationCombiningService(
            operationManager: operationManager
        ) {
            do {
                let price = try mainGasPriceWrapper.targetOperation.extractNoCancellableResultData()

                let resultWrapper = CompoundOperationWrapper.createWithResult(price)
                return [resultWrapper]
            } catch {
                logger.warning("Using fallback for gas price due to error: \(error)")

                let resultWrapper = fallbackProvider.getGasPriceWrapper()
                return [resultWrapper]
            }
        }
        .longrunOperation()

        fallbackOperation.addDependency(mainGasPriceWrapper.targetOperation)

        let mapOperation = ClosureOperation<BigUInt> {
            let optPrice = try fallbackOperation.extractNoCancellableResultData().first

            guard let price = optPrice else {
                throw CommonError.dataCorruption
            }

            return price
        }

        mapOperation.addDependency(fallbackOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: mainGasPriceWrapper.allOperations + [fallbackOperation]
        )
    }
}

extension EvmGasPriceWithFallbackProvider: EvmGasPriceProviderProtocol {
    func getGasPriceWrapper() -> CompoundOperationWrapper<BigUInt> {
        createWrapper(
            for: mainPriceProvider,
            fallbackProvider: fallbackPriceProvider,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )
    }
}
