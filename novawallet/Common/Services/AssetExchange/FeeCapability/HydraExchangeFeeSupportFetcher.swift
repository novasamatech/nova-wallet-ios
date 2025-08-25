import Foundation
import Operation_iOS
import SubstrateSdk

final class HydraExchangeFeeSupportFetcher {
    let chain: ChainModel
    let operationQueue: OperationQueue
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.operationQueue = operationQueue
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.logger = logger
    }
}

extension HydraExchangeFeeSupportFetcher: AssetExchangeFeeSupportFetching {
    var identifier: String { "hydra-fee-\(chain.chainId)" }

    func createFeeSupportWrapper() -> CompoundOperationWrapper<AssetExchangeFeeSupporting> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let keysFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
        let assetsFetchWrapper: CompoundOperationWrapper<[HydraDx.AssetsKey]> = keysFactory.createKeysFetchWrapper(
            by: HydraDx.feeCurrenciesPath,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        assetsFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<AssetExchangeFeeSupporting> {
            let allAssets = try assetsFetchWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let remoteLocalMapping = try HydraDxTokenConverter.convertToRemoteLocalMapping(
                remoteAssets: Set(allAssets.map(\.assetId)),
                chain: self.chain,
                codingFactory: codingFactory
            )

            let localFeeAssetIds = Set(remoteLocalMapping.values)

            return AssetExchangeFeeSupport(supportedAssets: localFeeAssetIds)
        }

        mapOperation.addDependency(codingFactoryOperation)
        mapOperation.addDependency(assetsFetchWrapper.targetOperation)

        return assetsFetchWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mapOperation)
    }
}
