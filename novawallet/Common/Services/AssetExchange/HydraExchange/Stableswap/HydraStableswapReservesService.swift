import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraStableswapReservesService: ObservableSubscriptionSyncService<HydraStableswap.ReservesRemoteState> {
    let poolAsset: HydraDx.AssetId

    init(
        poolAsset: HydraDx.AssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.poolAsset = poolAsset

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

    func getRequests(for poolAsset: HydraDx.AssetId) throws -> [BatchStorageSubscriptionRequest] {
        let poolAssetTotalIssuanceRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: StorageCodingPath.ormlTotalIssuance,
                localKey: "",
                keyParamClosure: {
                    StringScaleMapper(value: poolAsset)
                }
            ),
            mappingKey: HydraStableswap.ReservesRemoteStateChange.Key.poolIssuance.rawValue
        )

        return [poolAssetTotalIssuanceRequest]
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        try getRequests(for: poolAsset)
    }
}
