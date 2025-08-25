import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraStableswapPoolService: ObservableSubscriptionSyncService<HydraStableswap.PoolRemoteState> {
    let poolAsset: HydraDx.AssetId
    let assetIn: HydraDx.AssetId
    let assetOut: HydraDx.AssetId

    init(
        poolAsset: HydraDx.AssetId,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.poolAsset = poolAsset
        self.assetIn = assetIn
        self.assetOut = assetOut

        super.init(
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            repository: repository,
            workQueue: workQueue,
            retryStrategy: retryStrategy,
            logger: logger
        )
    }

    func getRequest(
        for poolAsset: HydraDx.AssetId,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId
    ) throws -> [BatchStorageSubscriptionRequest] {
        let poolRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraStableswap.pools,
                localKey: "",
                keyParamClosure: {
                    StringScaleMapper(value: poolAsset)
                }
            ),
            mappingKey: HydraStableswap.PoolRemoteStateChange.Key.poolInfo.rawValue
        )

        let tradabilityRequest = BatchStorageSubscriptionRequest(
            innerRequest: DoubleMapSubscriptionRequest(
                storagePath: HydraStableswap.tradability,
                localKey: "",
                keyParamClosure: {
                    (
                        StringScaleMapper(value: assetIn),
                        StringScaleMapper(value: assetOut)
                    )
                }
            ),
            mappingKey: HydraStableswap.PoolRemoteStateChange.Key.tradability.rawValue
        )

        let pegsInfo = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraStableswap.poolPegs,
                localKey: "",
                keyParamClosure: {
                    StringScaleMapper(value: poolAsset)
                }
            ),
            mappingKey: HydraStableswap.PoolRemoteStateChange.Key.pegsInfo.rawValue
        )

        let currentBlockRequest = BatchStorageSubscriptionRequest(
            innerRequest: UnkeyedSubscriptionRequest(
                storagePath: SystemPallet.blockNumberPath,
                localKey: ""
            ),
            mappingKey: HydraStableswap.PoolRemoteStateChange.Key.currentBlock.rawValue
        )

        return [poolRequest, tradabilityRequest, pegsInfo, currentBlockRequest]
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        try getRequest(
            for: poolAsset,
            assetIn: assetIn,
            assetOut: assetOut
        )
    }
}
