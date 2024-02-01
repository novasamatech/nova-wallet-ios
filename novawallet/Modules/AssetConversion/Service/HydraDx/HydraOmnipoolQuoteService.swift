import Foundation
import SubstrateSdk
import RobinHood

final class HydraOmnipoolQuoteService: ObservableSubscriptionSyncService<HydraDx.QuoteRemoteState> {
    let chain: ChainModel
    let assetIn: HydraDx.LocalRemoteAssetId
    let assetOut: HydraDx.LocalRemoteAssetId

    init(
        chain: ChainModel,
        assetIn: HydraDx.LocalRemoteAssetId,
        assetOut: HydraDx.LocalRemoteAssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chain = chain
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

    private func getBalanceRequest(
        for accountId: AccountId,
        assetId: HydraDx.LocalRemoteAssetId,
        mappingKeyClosure: (Bool) -> HydraDx.QuoteRemoteStateChange.Key
    ) -> BatchStorageSubscriptionRequest {
        if assetId.localAssetId == chain.utilityChainAssetId() {
            return .init(
                innerRequest: MapSubscriptionRequest(
                    storagePath: StorageCodingPath.account,
                    localKey: "",
                    keyParamClosure: {
                        BytesCodable(wrappedValue: accountId)
                    }
                ),
                mappingKey: mappingKeyClosure(true).rawValue
            )
        } else {
            return .init(
                innerRequest: DoubleMapSubscriptionRequest(
                    storagePath: StorageCodingPath.ormlTokenAccount,
                    localKey: "",
                    keyParamClosure: {
                        (BytesCodable(wrappedValue: accountId), StringScaleMapper(value: assetId.remoteAssetId))
                    },
                    param1Encoder: nil,
                    param2Encoder: nil
                ),
                mappingKey: mappingKeyClosure(false).rawValue
            )
        }
    }

    private func getFeeRequest(
        for assetId: HydraDx.LocalRemoteAssetId,
        mappingKey: HydraDx.QuoteRemoteStateChange.Key
    ) -> BatchStorageSubscriptionRequest {
        .init(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.dynamicFees,
                localKey: "",
                keyParamClosure: {
                    StringScaleMapper(value: assetId.remoteAssetId)
                }
            ),
            mappingKey: mappingKey.rawValue
        )
    }

    private func getAssetStateRequest(
        for assetId: HydraDx.LocalRemoteAssetId,
        mappingKey: HydraDx.QuoteRemoteStateChange.Key
    ) -> BatchStorageSubscriptionRequest {
        .init(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.omnipoolAssets,
                localKey: "",
                keyParamClosure: { StringScaleMapper(value: assetId.remoteAssetId) }
            ),
            mappingKey: mappingKey.rawValue
        )
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        let assetInStateRequest = getAssetStateRequest(
            for: assetIn,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetInState
        )

        let assetOutStateRequest = getAssetStateRequest(
            for: assetOut,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetOutState
        )

        let poolAccountId = try HydraDx.getPoolAccountId(for: chain.accountIdSize)

        let assetInBalanceRequest = getBalanceRequest(
            for: poolAccountId,
            assetId: assetIn,
            mappingKeyClosure: {
                $0 ? HydraDx.QuoteRemoteStateChange.Key.assetInNativeBalance :
                    HydraDx.QuoteRemoteStateChange.Key.assetInOrmlBalance
            }
        )
        let assetOutBalanceRequest = getBalanceRequest(
            for: poolAccountId,
            assetId: assetOut,
            mappingKeyClosure: {
                $0 ? HydraDx.QuoteRemoteStateChange.Key.assetOutNativeBalance :
                    HydraDx.QuoteRemoteStateChange.Key.assetOutOrmlBalance
            }
        )

        let assetInFeeRequest = getFeeRequest(
            for: assetIn,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetInFee
        )

        let assetOutFeeRequest = getFeeRequest(
            for: assetOut,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetOutFee
        )

        return [
            assetInStateRequest,
            assetOutStateRequest,
            assetInBalanceRequest,
            assetOutBalanceRequest,
            assetInFeeRequest,
            assetOutFeeRequest
        ]
    }
}
