import Foundation
import SubstrateSdk
import RobinHood

protocol RuntimePolicyServiceProtocol: ApplicationServiceProtocol {
    func update(wallet: MetaAccountModel)
}

final class RuntimePolicyService {
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol
    let accountDetector: ChainRemoteAccountDetecting
    let workingQueue = DispatchQueue.global(qos: .userInitiated)

    private var selectedWallet: MetaAccountModel?

    init(selectedWallet: MetaAccountModel?, chainRegistry: ChainRegistryProtocol, logger: LoggerProtocol) {
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.logger = logger

        accountDetector = SubstrateRemoteAccountDetector(logger: logger)
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(chain), let .update(chain):
                let request = chain.accountRequest()

                // manage runtime sync only for substrate networks
                guard !chain.isReadyForOnchainRequests && chain.isLightSyncMode else {
                    accountDetector.stopTrackingAccount(for: chain.chainId)
                    return
                }

                guard let accountId = selectedWallet?.fetch(for: request)?.accountId else {
                    logger.warning("No account for \(chain.name) \(chain.chainId)")
                    return
                }

                guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
                    logger.error("No connection for \(chain.name) \(chain.chainId)")
                    return
                }

                do {
                    try accountDetector.startTracking(
                        accountId: accountId,
                        chain: chain,
                        connection: connection
                    )
                } catch {
                    logger.error("Can't track account for \(chain.name) \(error)")
                }
            case let .delete(deletedIdentifier):
                accountDetector.stopTrackingAccount(for: deletedIdentifier)
            }
        }
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: workingQueue) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    private func unsubscribeChains() {
        chainRegistry.chainsUnsubscribe(self)
    }
}

extension RuntimePolicyService: ChainRemoteAccountDetectorDelegate {
    func didReceiveDetected(account: ChainRemoteDetectedAccount, accountId: AccountId, chain: ChainModel) {
        let request = chain.accountRequest()

        guard
            let currentAccountId = selectedWallet?.fetch(for: request)?.accountId,
            currentAccountId == accountId else {
            return
        }

        if account.exists {
            do {
                try chainRegistry.switchSync(mode: .full, chainId: chain.chainId)
            } catch {
                logger.error("Can't switch full sync \(chain.name) \(chain.chainId)")
            }
        }
    }
}

extension RuntimePolicyService: RuntimePolicyServiceProtocol {
    func setup() {
        accountDetector.delegate = self
        accountDetector.callbackQueue = .global(qos: .userInitiated)

        subscribeChains()
    }

    func throttle() {
        unsubscribeChains()
        accountDetector.stopTrackingAll()
    }

    func update(wallet _: MetaAccountModel) {
        unsubscribeChains()
        accountDetector.stopTrackingAll()

        subscribeChains()
    }
}
