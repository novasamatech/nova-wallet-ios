import Foundation
import Foundation_iOS
import Operation_iOS
import BigInt

final class MultisigNotificationMessageHandler: WalletSelectingNotificationHandling {
    let chainRegistry: ChainRegistryProtocol
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    let callFormattingFactory: CallFormattingOperationFactoryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    let multisigEndedMessageFactory: MultisigEndedMessageFactoryProtocol

    let callStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        callFormattingFactory: CallFormattingOperationFactoryProtocol,
        multisigEndedMessageFactory: MultisigEndedMessageFactoryProtocol = MultisigEndedMessageFactory(),
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.eventCenter = eventCenter
        self.settingsRepository = settingsRepository
        self.walletsRepository = walletsRepository
        self.callFormattingFactory = callFormattingFactory
        self.multisigEndedMessageFactory = multisigEndedMessageFactory
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
        getChain(for: chainId) { [weak self] chain in
            self?.handleOperationOpen(
                chain: chain,
                payload: payload,
                completion: completion
            )
        }
    }

    func handleOperationExecuted(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        getChain(for: chainId) { [weak self] chain in
            self?.handleOperationExecuted(
                chain: chain,
                callData: payload.callData,
                completion: completion
            )
        }
    }

    func handleOperationCancelled(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        getChain(for: chainId) { [weak self] chain in
            self?.handleOperationCancelled(
                chain: chain,
                cancellerAddress: payload.signatoryAddress,
                callData: payload.callData,
                completion: completion
            )
        }
    }

    func getChain(
        for chainId: ChainModel.Id,
        completion: @escaping (ChainModel) -> Void
    ) {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue
        ) { [weak self] changes in
            guard let self else { return }

            let chains: [ChainModel] = changes.allChangedItems()

            guard let chain = chains.first(where: {
                Web3Alert.createRemoteChainId(from: $0.chainId) == chainId
            }) else {
                return
            }

            chainRegistry.chainsUnsubscribe(self)

            completion(chain)
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
            successClosure: { completion(.success(.multisigOperationDetails(.key(key)))) },
            failureClosure: { completion(.failure($0)) }
        )
    }

    func handleOperationExecuted(
        chain: ChainModel,
        callData: Substrate.CallData?,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        let wrapper = createExecutedMessageWrapper(
            chain: chain,
            callData: callData
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { result in
            switch result {
            case let .success(messageModel):
                completion(.success(.multisigOperationEnded(messageModel)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func handleOperationCancelled(
        chain: ChainModel,
        cancellerAddress: AccountAddress,
        callData: Substrate.CallData?,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        let wrapper = createCancelledMessageWrapper(
            chain: chain,
            cancellerAddress: cancellerAddress,
            callData: callData
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { result in
            switch result {
            case let .success(messageModel):
                completion(.success(.multisigOperationEnded(messageModel)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func createCancelledMessageWrapper(
        chain: ChainModel,
        cancellerAddress: AccountAddress,
        callData: Substrate.CallData?
    ) -> CompoundOperationWrapper<MultisigEndedMessageModel> {
        guard let callData else {
            let message = multisigEndedMessageFactory.createRejectedMessageModel(
                for: chain,
                cancellerAddress: cancellerAddress
            )
            return .createWithResult(message)
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: chain.chainId
        )

        let resultOperation = ClosureOperation<MultisigEndedMessageModel> {
            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()
            let messageModel = self.multisigEndedMessageFactory.createRejectedMessageModel(
                for: formattedCall,
                cancellerAddress: cancellerAddress,
                chain: chain
            )

            return messageModel
        }

        resultOperation.addDependency(formattedCallWrapper.targetOperation)

        return formattedCallWrapper.insertingTail(operation: resultOperation)
    }

    func createExecutedMessageWrapper(
        chain: ChainModel,
        callData: Substrate.CallData?
    ) -> CompoundOperationWrapper<MultisigEndedMessageModel> {
        guard let callData else {
            let message = multisigEndedMessageFactory.createExecutedMessageModel(for: chain)
            return .createWithResult(message)
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: chain.chainId
        )

        let resultOperation = ClosureOperation<MultisigEndedMessageModel> {
            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()
            let messageModel = self.multisigEndedMessageFactory.createExecutedMessageModel(
                for: formattedCall,
                chain: chain
            )

            return messageModel
        }

        resultOperation.addDependency(formattedCallWrapper.targetOperation)

        return formattedCallWrapper.insertingTail(operation: resultOperation)
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
            handleOperationExecuted(
                chainId: chainId,
                payload: payload,
                completion: completion
            )
        case let .multisigCancelled(chainId, payload):
            handleOperationCancelled(
                chainId: chainId,
                payload: payload,
                completion: completion
            )
        default:
            completion(.failure(MultisigNotificationHandlingError.unsupportedMessage))
            return
        }
    }

    func cancel() {
        chainRegistry.chainsUnsubscribe(self)
    }
}
