import Foundation
import SubstrateSdk
import Operation_iOS

typealias CrowdloanContributionChange = BatchGenericSubscriptionChange<AhOpsPallet.Contribution>

final class CrowdloanOnChainSyncService: BaseSyncService {
    private let operationFactory: AhOpsOperationFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let accountId: AccountId
    private let chainId: ChainModel.Id
    private let repository: AnyDataProviderRepository<CrowdloanContribution>
    private let operationQueue: OperationQueue
    private let syncQueue: DispatchQueue

    private let crowdloanCancellable = CancellableCallStore()
    private var state: [String: CrowdloanContribution] = [:]
    var subscription: CallbackBatchStorageSubscription<CrowdloanContributionChange>?

    init(
        operationFactory: AhOpsOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<CrowdloanContribution>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operationFactory = operationFactory
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.accountId = accountId
        self.operationQueue = operationQueue
        syncQueue = DispatchQueue(label: "io.crowdloan.onchain.sync")
        self.chainId = chainId

        super.init(logger: logger)
    }

    override func performSyncUp() {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            logger.error("Connection for chainId: \(chainId) is unavailable")
            completeImmediate(ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger.error("Runtime metadata for chainId: \(chainId) is unavailable")
            completeImmediate(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        crowdloanCancellable.cancel()

        logger.debug("Fetching crowdloans for: \(chainId)")

        let crowdloansWrapper = operationFactory.fetchCrowdloans(by: chainId)

        executeCancellable(
            wrapper: crowdloansWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: crowdloanCancellable,
            runningCallbackIn: syncQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(mapping):
                logger.debug("Crowdloans fetched: \(chainId) \(mapping.count)")
                subscribeContributions(
                    for: Set(mapping.keys),
                    connection: connection,
                    runtimeService: runtimeService
                )
            case let .failure(error):
                logger.error("Crowdloans fetched failed: \(chainId) \(error)")
                completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        crowdloanCancellable.cancel()
        clearContributionSubscription()
    }
}

private extension CrowdloanOnChainSyncService {
    func clearContributionSubscription() {
        subscription?.unsubscribe()
        subscription = nil
    }

    func subscribeContributions(
        for crowdloanKeys: Set<AhOpsPallet.ContributionKey>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        clearContributionSubscription()

        let contributionKeys = crowdloanKeys.map { key in
            AhOpsPallet.ContributionKey(
                blockNumber: key.blockNumber,
                paraId: key.paraId,
                contributor: accountId
            )
        }

        let contributionRequests = contributionKeys.map { contributionKey in
            BatchStorageSubscriptionRequest(
                innerRequest: NMapSubscriptionRequest(
                    storagePath: AhOpsPallet.rcCrowdloanContributionPath,
                    localKey: "",
                    keyParams: contributionKey
                ),
                mappingKey: contributionKey.rawIdentifier
            )
        }

        let depositors = crowdloanKeys.reduce(into: [ParaId: AccountId]()) {
            $0[$1.paraId] = $1.contributor
        }

        logger.debug("Subscribing contributions: \(chainId)")

        subscription = CallbackBatchStorageSubscription(
            requests: contributionRequests,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: syncQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            switch result {
            case let .success(change):
                handle(contributionKeys: contributionKeys, depositors: depositors, change: change)
            case let .failure(error):
                logger.error("Contributions subscription failed: \(chainId) \(error)")
                completeImmediate(error)
            }
        }

        subscription?.subscribe()
    }

    func handle(
        contributionKeys: [AhOpsPallet.ContributionKey],
        depositors: [ParaId: AccountId],
        change: CrowdloanContributionChange
    ) {
        contributionKeys.forEach { contributionKey in
            guard
                let update = change.values[contributionKey.rawIdentifier],
                case let .defined(optValue) = update,
                let depositor = depositors[contributionKey.paraId] else {
                return
            }

            if let newValue = optValue {
                state[contributionKey.rawIdentifier] = CrowdloanContribution(
                    accountId: contributionKey.contributor,
                    chainAssetId: ChainAssetId(chainId: chainId, assetId: AssetModel.utilityAssetId),
                    paraId: contributionKey.paraId,
                    unlocksAt: contributionKey.blockNumber,
                    amount: newValue.amount,
                    depositor: depositor
                )
            } else {
                state[contributionKey.rawIdentifier] = nil
            }
        }

        let allContributions = Array(state.values)

        let replaceOperation = repository.replaceOperation {
            allContributions
        }

        execute(
            operation: replaceOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            switch result {
            case .success:
                logger.debug("Contributions synced: \(chainId)")
                completeImmediate(nil)
            case let .failure(error):
                completeImmediate(error)
            }
        }
    }
}
