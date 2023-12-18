import Foundation
import SubstrateSdk

protocol ChainRemoteAccountDetecting: AnyObject {
    var delegate: ChainRemoteAccountDetectorDelegate? { get set }
    var callbackQueue: DispatchQueue { get set }

    func startTracking(accountId: AccountId, chain: ChainModel, connection: JSONRPCEngine) throws
    func stopTrackingAccount(for chainId: ChainModel.Id)
    func stopTrackingAll()
}

protocol ChainRemoteAccountDetectorDelegate: AnyObject {
    func didDetectAccount(for accountId: AccountId, chain: ChainModel)
}

final class SubstrateRemoteAccountDetector {
    weak var delegate: ChainRemoteAccountDetectorDelegate?
    var callbackQueue: DispatchQueue = .global()

    let logger: LoggerProtocol

    private var subscriptions: [ChainModel.Id: SyncServiceProtocol] = [:]

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension SubstrateRemoteAccountDetector: ChainRemoteAccountDetecting {
    func startTracking(accountId: AccountId, chain: ChainModel, connection: JSONRPCEngine) throws {
        guard subscriptions[chain.chainId] == nil else {
            return
        }

        let syncService = ChainRemoteAccountConfirmService(
            accountId: accountId,
            connection: connection,
            shouldConfirm: true,
            detectionClosure: { [weak self] in
                self?.delegate?.didDetectAccount(for: accountId, chain: chain)
            },
            callbackQueue: callbackQueue,
            logger: logger
        )

        subscriptions[chain.chainId] = syncService
        syncService.setup()
    }

    func stopTrackingAccount(for chainId: ChainModel.Id) {
        subscriptions[chainId]?.stopSyncUp()
        subscriptions[chainId] = nil
    }

    func stopTrackingAll() {
        subscriptions.forEach { $0.value.stopSyncUp() }

        subscriptions = [:]
    }
}
