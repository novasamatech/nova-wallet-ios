import Foundation

enum EvmGasLimitProviderFactory {
    static func createGasLimitProvider(
        for asset: AssetModel,
        operationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> EvmGasLimitProviderProtocol {
        let fallbackGasLimit = EvmFallbackGasLimit.value(for: asset)

        let fallbackProvider = EvmConstantGasLimitProvider(value: fallbackGasLimit)
        let defaultProvider = EvmDefaultGasLimitProvider(operationFactory: operationFactory)

        return EvmGasLimitFallbackProvider(
            mainProvider: defaultProvider,
            fallbackProvider: fallbackProvider,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
