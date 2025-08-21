import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS

final class AssetDetailsNotificationMessageHandler: WalletSelectingNotificationHandling {
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

private extension AssetDetailsNotificationMessageHandler {
    func handle(
        parameters: ResolvedParameters,
        completion: @escaping (Result<ChainAsset, Error>) -> Void
    ) {
        guard let address = parameters.address else {
            completion(.failure(AssetDetailsHandlingError.invalidAddress))
            return
        }

        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue
        ) { [weak self] changes in
            guard let self = self else {
                return
            }
            let chains: [ChainModel] = changes.allChangedItems()

            guard let chainModel = chains.first(where: {
                Web3Alert.createRemoteChainId(from: $0.chainId) == parameters.chainId
            }) else {
                return
            }

            self.chainRegistry.chainsUnsubscribe(self)

            self.handle(
                chain: chainModel,
                assetId: parameters.assetId,
                address: address,
                completion: completion
            )
        }
    }

    func handle(
        chain: ChainModel,
        assetId: String?,
        address: AccountAddress,
        completion: @escaping (Result<ChainAsset, Error>) -> Void
    ) {
        guard let asset = mapAssetId(assetId, chain: chain) else {
            completion(.failure(AssetDetailsHandlingError.invalidAssetId))
            return
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        trySelectWallet(
            with: address,
            chainId: chain.chainId,
            successClosure: { completion(.success(chainAsset)) },
            failureClosure: { completion(.failure($0)) }
        )
    }

    func mapAssetId(_ assetId: String?, chain: ChainModel) -> AssetModel? {
        if assetId == nil {
            return chain.utilityAsset()
        } else {
            return chain.asset(byHistoryAssetId: assetId)
        }
    }

    func handleParsedMessage(
        _ parameters: ResolvedParameters,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        handle(parameters: parameters) {
            switch $0 {
            case let .success(chainAsset):
                completion(.success(.historyDetails(chainAsset)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - PushNotificationMessageHandlingProtocol

extension AssetDetailsNotificationMessageHandler: PushNotificationMessageHandlingProtocol {
    func handle(
        message: NotificationMessage,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        switch message {
        case let .stakingReward(chainId, payload):
            let resolvedParameters = ResolvedParameters(chainId: chainId, assetId: nil, address: payload.recipient)
            handleParsedMessage(resolvedParameters, completion: completion)
        case let .transfer(type, chainId, payload):
            let address = type == .income ? payload.recipient : payload.sender
            let resolvedParameters = ResolvedParameters(chainId: chainId, assetId: payload.assetId, address: address)
            handleParsedMessage(resolvedParameters, completion: completion)
        default:
            completion(.failure(AssetDetailsHandlingError.unsupportedMessage))
            return
        }
    }

    func cancel() {
        chainRegistry.chainsUnsubscribe(self)
    }
}

// MARK: - Private types

private extension AssetDetailsNotificationMessageHandler {
    struct ResolvedParameters {
        let chainId: ChainModel.Id
        let assetId: String?
        let address: AccountAddress?
    }
}
