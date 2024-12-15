import Foundation
import SubstrateSdk
import Operation_iOS

class HydraSwapFeeCurrencyService: ObservableSubscriptionSyncService<HydraDx.SwapFeeCurrencyState> {
    let payerAccountId: AccountId

    init(
        payerAccountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.payerAccountId = payerAccountId

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
        let feeCurrencyRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.accountFeeCurrencyPath,
                localKey: "",
                keyParamClosure: { BytesCodable(wrappedValue: accountId) }
            ),
            mappingKey: HydraDx.SwapFeeCurrencyStateChange.Key.feeCurrency.rawValue
        )

        return [feeCurrencyRequest]
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        getRequests(for: payerAccountId)
    }
}
