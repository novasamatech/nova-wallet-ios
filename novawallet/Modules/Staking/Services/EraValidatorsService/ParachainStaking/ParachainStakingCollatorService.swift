import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

final class ParachainStakingCollatorService {
    static let queueLabelPrefix = "com.novawallet.selected.collators"

    private struct PendingRequest {
        let resultClosure: (SelectedRoundCollators) -> Void
        let queue: DispatchQueue?
    }

    let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private(set) var roundInfo: ParachainStaking.RoundInfo?
    private(set) var collatorCommission: BigUInt?
    private var isActive: Bool = false

    private var snapshot: SelectedRoundCollators?
    private var roundProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    private var collatorCommissionProvider: AnyDataProvider<DecodedBigUInt>?
    private var pendingRequests: [UUID: PendingRequest] = [:]

    var syncService: StorageListSyncService<
        String,
        ParachainStaking.CollatorSnapshotKey,
        ParachainStaking.CollatorSnapshot
    >?

    let chainId: ChainModel.Id
    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(
        chainId: ChainModel.Id,
        storageFacade: StorageFacadeProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.storageFacade = storageFacade
        self.runtimeCodingService = runtimeCodingService
        self.connection = connection
        self.providerFactory = providerFactory
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func didReceiveSnapshot(_ snapshot: SelectedRoundCollators) {
        logger.debug("Attempt fulfill pendings \(pendingRequests.count)")

        self.snapshot = snapshot

        if !pendingRequests.isEmpty {
            let requests = pendingRequests
            pendingRequests = [:]

            requests.values.forEach { deliver(snapshot: snapshot, to: $0) }

            logger.debug("Fulfilled pendings")
        }

        DispatchQueue.main.async {
            let event = EraStakersInfoChanged(chainId: self.chainId)
            self.eventCenter.notify(with: event)
        }
    }

    private func fetchInfoFactory(
        assigning requestId: UUID,
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (SelectedRoundCollators) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests[requestId] = request
        }
    }

    private func cancel(for requestId: UUID) {
        pendingRequests[requestId] = nil
    }

    private func deliver(snapshot: SelectedRoundCollators, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(snapshot)
        }
    }

    private func subscribe() {
        do {
            try subscribeRound()
            try subscribeCollatorCommission()
        } catch {
            unsubscribe()

            logger.error("Can't make subscription")
        }
    }

    private func subscribeRound() throws {
        guard roundProvider == nil else {
            return
        }

        roundProvider = try providerFactory.getRoundProvider(for: chainId)

        let updateClosure: ([DataProviderChange<ParachainStaking.DecodedRoundInfo>]) -> Void

        updateClosure = { [weak self] changes in
            let value = changes.reduceToLastChange()

            let oldRoundInfo = self?.roundInfo
            self?.roundInfo = value?.item

            if let roundInfo = self?.roundInfo, oldRoundInfo != roundInfo {
                self?.didUpdateRoundInfo(roundInfo)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger.error("Did receive error: \(error)")
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        roundProvider?.addObserver(
            self,
            deliverOn: syncQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subscribeCollatorCommission() throws {
        guard collatorCommissionProvider == nil else {
            return
        }

        collatorCommissionProvider = try providerFactory.getCollatorCommissionProvider(for: chainId)

        let updateClosure: ([DataProviderChange<DecodedBigUInt>]) -> Void

        updateClosure = { [weak self] changes in
            let value = changes.reduceToLastChange()

            let oldCollatorCommission = self?.collatorCommission
            self?.collatorCommission = value?.item?.value

            if
                let collatorCommission = self?.collatorCommission,
                oldCollatorCommission != collatorCommission {
                self?.didUpdateCollatorCommission(collatorCommission)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger.error("Did receive error: \(error)")
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        collatorCommissionProvider?.addObserver(
            self,
            deliverOn: syncQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func unsubscribe() {
        roundProvider?.removeObserver(self)
        roundProvider = nil

        collatorCommissionProvider?.removeObserver(self)
        collatorCommissionProvider = nil

        syncService?.throttle()
        syncService = nil
    }
}

extension ParachainStakingCollatorService: ParachainStakingCollatorServiceProtocol {
    func setup() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true

            self.subscribe()
        }
    }

    func throttle() {
        syncQueue.async {
            guard self.isActive else {
                return
            }

            self.isActive = false

            self.unsubscribe()
        }
    }

    func fetchInfoOperation() -> BaseOperation<SelectedRoundCollators> {
        let requestId = UUID()

        return AsyncClosureOperation(
            operationClosure: { closure in
                self.syncQueue.async {
                    self.fetchInfoFactory(assigning: requestId, runCompletionIn: nil) { info in
                        closure(.success(info))
                    }
                }
            },
            cancelationClosure: {
                self.syncQueue.async {
                    self.cancel(for: requestId)
                }
            }
        )
    }
}
