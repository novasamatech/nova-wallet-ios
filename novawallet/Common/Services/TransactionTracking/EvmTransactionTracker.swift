import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmTransactionTracker {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let processingQueue = DispatchQueue(label: "io.novawallet.transaction.tracking.evm")
    let logger: LoggerProtocol

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue, logger: LoggerProtocol) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - ChainTransactionTracking

extension EvmTransactionTracker: ChainTransactionTracking {
    func canTrack(chain: ChainModel) -> Bool {
        chain.isEthereumBased
    }

    func startWatch(
        for request: TransactionTrackingRequest,
        chain: ChainModel,
        onResult: @escaping (TransactionWatchResult) -> Void
    ) throws -> TransactionWatching {
        switch request.evidence {
        case let .evm(evidence):
            return try startWatch(for: request, evidence: evidence, chain: chain, onResult: onResult)
        }
    }
}

extension EvmTransactionTracker {
    static func watchedNonce(from nonce: BigUInt?, mode: TransactionTrackingMode) -> BigUInt? {
        guard case let .recovered(rowAge) = mode, rowAge >= Constants.recoveredWatchLimit else {
            return nonce
        }

        return nil
    }
}

// MARK: - Private

private extension EvmTransactionTracker {
    enum Constants {
        static let recoveredWatchLimit: TimeInterval = 24 * 60 * 60
    }

    func startWatch(
        for request: TransactionTrackingRequest,
        evidence: EvmTrackingEvidence,
        chain: ChainModel,
        onResult: @escaping (TransactionWatchResult) -> Void
    ) throws -> TransactionWatching {
        let oneShotConnection: JSONRPCEngine? = chainRegistry.getOneShotConnection(for: chain.chainId)

        guard let connection = oneShotConnection ?? chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let watcher = EvmTransactionWatcher(
            queryOperationFactory: EvmWebSocketOperationFactory(
                connection: connection,
                timeout: JSONRPCTimeout.withNodeSwitch
            ),
            headsConnection: nil,
            timing: EvmTransactionMonitorTiming(chain: chain),
            processingQueue: processingQueue,
            operationQueue: operationQueue,
            logger: logger
        )

        let transaction = EvmSubmittedTransaction(
            transactionHash: request.key.transactionHash,
            sender: evidence.sender,
            nonce: Self.watchedNonce(from: evidence.nonce, mode: request.mode)
        )

        processingQueue.async {
            switch request.mode {
            case .fresh:
                watcher.start(watching: transaction, deadline: nil, completion: onResult)
            case let .recovered(rowAge):
                watcher.start(
                    watching: transaction,
                    submittedAt: Date().addingTimeInterval(-rowAge),
                    deadline: Constants.recoveredWatchLimit,
                    completion: onResult
                )
            }
        }

        if request.mode.isRecovered {
            watcher.checkNow()
        }

        return watcher
    }
}

extension EvmTransactionWatcher: TransactionWatching {}
