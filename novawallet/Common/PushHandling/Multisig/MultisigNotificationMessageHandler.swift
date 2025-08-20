import Foundation
import Foundation_iOS
import Operation_iOS

final class MultisigNotificationMessageHandler: WalletSelectingNotificationHandling {
    let chainRegistry: ChainRegistryProtocol
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    let callStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.eventCenter = eventCenter
        self.settingsRepository = settingsRepository
        self.walletsRepository = walletsRepository
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }
}

// MARK: - Private

private extension MultisigNotificationMessageHandler {
    func handleOperationOpen(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue
        ) { [weak self] changes in
            guard let self else {
                return
            }

            let chains: [ChainModel] = changes.allChangedItems()

            guard let chain = chains.first(where: {
                Web3Alert.createRemoteChainId(from: $0.chainId) == chainId
            }) else {
                return
            }

            chainRegistry.chainsUnsubscribe(self)

            handleOperationOpen(
                chain: chain,
                payload: payload,
                completion: completion
            )
        }
    }

    func handleOperationOpen(
        chain: ChainModel,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        guard
            let multisigAccountId = try? payload.multisigAddress.toAccountId(),
            let signatoryAccountId = try? payload.signatoryAddress.toAccountId()
        else {
            completion(.failure(MultisigNotificationHandlingError.invalidAddress))
            return
        }

        let key = Multisig.PendingOperation.Key(
            callHash: payload.callHash,
            chainId: chain.chainId,
            multisigAccountId: multisigAccountId
        )

        trySelectWallet(
            with: payload.multisigAddress,
            chainId: chain.chainId,
            filter: { $0.multisigAccount?.anyChainMultisig?.signatory != signatoryAccountId },
            successClosure: { completion(.success(.multisigOperation(.key(key)))) },
            failureClosure: { completion(.failure($0)) }
        )
    }
}

// MARK: - PushNotificationMessageHandlingProtocol

extension MultisigNotificationMessageHandler: PushNotificationMessageHandlingProtocol {
    func handle(
        message: NotificationMessage,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        switch message {
        case let .newMultisig(chainId, payload), let .multisigApproval(chainId, payload):
            handleOperationOpen(
                chainId: chainId,
                payload: payload,
                completion: completion
            )
        case let .multisigExecuted(chainId, payload):
            completion(.failure(MultisigNotificationHandlingError.unsupportedMessage))
            return
        case let .multisigCancelled(chainId, payload):
            completion(.failure(MultisigNotificationHandlingError.unsupportedMessage))
            return
        default:
            completion(.failure(MultisigNotificationHandlingError.unsupportedMessage))
            return
        }
    }

    func cancel() {}
}
