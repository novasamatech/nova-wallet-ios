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
    func didReceiveDetected(account: ChainRemoteDetectedAccount, accountId: AccountId, chain: ChainModel)
}

struct ChainRemoteDetectedAccount {
    let exists: Bool
}

final class SubstrateRemoteAccountDetector {
    weak var delegate: ChainRemoteAccountDetectorDelegate?
    var callbackQueue: DispatchQueue = .global()

    let storageKeyFactory = StorageKeyFactory()

    let logger: LoggerProtocol

    private var subscriptions: [ChainModel.Id: StorageSubscriptionContainer] = [:]

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension SubstrateRemoteAccountDetector: ChainRemoteAccountDetecting {
    func startTracking(accountId: AccountId, chain: ChainModel, connection: JSONRPCEngine) throws {
        guard subscriptions[chain.chainId] == nil else {
            return
        }

        let remoteKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        let handler = RawDataStorageSubscription(remoteStorageKey: remoteKey) { [weak self] data, _ in
            let hasAccount = data != nil

            self?.callbackQueue.async {
                self?.delegate?.didReceiveDetected(
                    account: .init(exists: hasAccount),
                    accountId: accountId,
                    chain: chain
                )
            }
        }

        let container = StorageSubscriptionContainer(
            engine: connection,
            children: [handler],
            logger: logger
        )

        subscriptions[chain.chainId] = container
    }

    func stopTrackingAccount(for chainId: ChainModel.Id) {
        subscriptions[chainId] = nil
    }

    func stopTrackingAll() {
        subscriptions = [:]
    }
}
