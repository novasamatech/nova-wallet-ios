import Foundation
import Operation_iOS
import BigInt

final class PendingTransactionPickup {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let trackers: [ChainTransactionTracking]
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        trackers: [ChainTransactionTracking],
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
        self.trackers = trackers
        self.logger = logger
    }
}

// MARK: - PendingTransactionPickupProtocol

extension PendingTransactionPickup: PendingTransactionPickupProtocol {
    func createRequestsWrapper() -> CompoundOperationWrapper<[TransactionTrackingRequest]> {
        let repository: CoreDataRepository<TransactionHistoryItem, CDTransactionItem> =
            storageFacade.createRepository(filter: .filterTransactionsBy(status: .pending), sortDescriptors: [])

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<[TransactionTrackingRequest]> { [weak self] in
            let rows = try fetchOperation.extractNoCancellableResultData()

            return self?.createRequests(from: rows, now: Date()) ?? []
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}

// MARK: - Private

private extension PendingTransactionPickup {
    func createRequests(from rows: [TransactionHistoryItem], now: Date) -> [TransactionTrackingRequest] {
        var requests: [TransactionTrackingKey: TransactionTrackingRequest] = [:]
        var waitingForChains = 0

        for row in rows {
            guard let chain = chainRegistry.getChain(for: row.chainId) else {
                waitingForChains += 1
                continue
            }

            guard
                let request = createRequest(from: row, chain: chain, now: now),
                requests[request.key] == nil else {
                continue
            }

            requests[request.key] = request
        }

        let waitingDescription = "\(waitingForChains) waiting for chains"
        logger.debug("Tracking: pickup \(rows.count) pending rows, \(requests.count) requests, \(waitingDescription)")

        return Array(requests.values)
    }

    func createRequest(
        from row: TransactionHistoryItem,
        chain: ChainModel,
        now: Date
    ) -> TransactionTrackingRequest? {
        guard
            trackers.contains(where: { $0.canTrack(chain: chain) }),
            row.source != .substrate || chain.isPureEvm,
            let sender = try? row.sender.toAccountId(using: chain.chainFormat) else {
            return nil
        }

        let rowAge = max(0, now.timeIntervalSince1970 - TimeInterval(row.timestamp))

        return TransactionTrackingRequest(
            key: TransactionTrackingKey(chainId: row.chainId, transactionHash: row.txHash),
            evidence: .evm(EvmTrackingEvidence(sender: sender, nonce: row.nonce.flatMap { BigUInt($0) })),
            mode: .recovered(rowAge: rowAge)
        )
    }
}
