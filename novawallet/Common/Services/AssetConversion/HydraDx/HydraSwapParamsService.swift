import Foundation
import SubstrateSdk
import Operation_iOS

class HydraSwapParamsService: ObservableSubscriptionSyncService<HydraDx.SwapRemoteState> {
    let accountId: AccountId

    init(
        accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId

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

    func getRequests(for accountId: AccountId) -> [BatchStorageSubscriptionRequest] {
        let referralRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.referralLinkedAccountPath,
                localKey: "",
                keyParamClosure: { BytesCodable(wrappedValue: accountId) }
            ),
            mappingKey: HydraDx.SwapRemoteStateChange.Key.referralLink.rawValue
        )

        return [referralRequest]
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        getRequests(for: accountId)
    }
}
