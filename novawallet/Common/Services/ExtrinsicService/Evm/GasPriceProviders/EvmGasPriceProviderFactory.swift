import Foundation
import SubstrateSdk

enum EvmGasPriceProviderFactory {
    static func createMaxPriorityWithLegacyFallback(
        operationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> EvmGasPriceProviderProtocol {
        let maxPriorityProvider = EvmMaxPriorityGasPriceProvider(operationFactory: operationFactory)
        let legacyProvider = EvmLegacyGasPriceProvider(operationFactory: operationFactory)

        return EvmGasPriceWithFallbackProvider(
            mainPriceProvider: maxPriorityProvider,
            fallbackPriceProvider: legacyProvider,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
