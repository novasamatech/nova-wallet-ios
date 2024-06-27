import Foundation
import SoraFoundation
import SoraKeystore
import Operation_iOS

final class AssetDetailsNotificationMessageHandler {
    private let chainRegistry: ChainRegistryProtocol
    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol
    private let settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    private let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let callbackStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.eventCenter = eventCenter
        self.settingsRepository = settingsRepository
        self.walletsRepository = walletsRepository
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }

    func cancel() {
        chainRegistry.chainsUnsubscribe(self)
    }

    private func handle(
        parameters: ResolvedParameters,
        completion: @escaping (Result<ChainAsset, AssetDetailsHandlingError>) -> Void
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

    private func handle(
        chain: ChainModel,
        assetId: String?,
        address: AccountAddress,
        completion: @escaping (Result<ChainAsset, AssetDetailsHandlingError>) -> Void
    ) {
        guard let asset = mapAssetId(assetId, chain: chain) else {
            completion(.failure(AssetDetailsHandlingError.invalidAssetId))
            return
        }

        let settingsOperation = settingsRepository.fetchAllOperation(with: .init())
        let walletsOperation = walletsRepository.fetchAllOperation(with: .init())

        let mapOperation = ClosureOperation {
            let wallets = try settingsOperation.extractNoCancellableResultData().first?.wallets ?? []
            let metaAccounts = try walletsOperation.extractNoCancellableResultData()

            let wallet = Self.targetWallet(
                address: address,
                chainId: chain.chainId,
                pushNotificationWallets: wallets,
                metaAccounts: metaAccounts
            )

            return wallet
        }
        mapOperation.addDependency(settingsOperation)
        mapOperation.addDependency(walletsOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [settingsOperation, walletsOperation]
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callbackStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(result):
                self?.trySelect(
                    wallet: result,
                    chainAsset: .init(chain: chain, asset: asset),
                    completion: completion
                )
            case let .failure(error):
                completion(.failure(AssetDetailsHandlingError.select(error)))
            }
        }
    }

    private func trySelect(
        wallet: MetaAccountModel?,
        chainAsset: ChainAsset,
        completion: @escaping (Result<ChainAsset, AssetDetailsHandlingError>) -> Void
    ) {
        guard let wallet = wallet else {
            completion(.failure(AssetDetailsHandlingError.unknownWallet))
            return
        }

        select(wallet: wallet) { error in
            if let error = error {
                completion(.failure(AssetDetailsHandlingError.select(error)))
            } else {
                completion(.success(chainAsset))
            }
        }
    }

    private func mapAssetId(_ assetId: String?, chain: ChainModel) -> AssetModel? {
        if assetId == nil {
            return chain.utilityAsset()
        } else {
            return chain.asset(byHistoryAssetId: assetId)
        }
    }

    private static func targetWallet(
        address: AccountAddress,
        chainId: ChainModel.Id,
        pushNotificationWallets: [Web3Alert.LocalWallet],
        metaAccounts: [MetaAccountModel]
    ) -> MetaAccountModel? {
        guard let targetWallet = pushNotificationWallets.first(where: {
            if let specificAddress = $0.model.chainSpecific[chainId] {
                return specificAddress == address
            } else {
                return $0.model.baseSubstrate == address ||
                    $0.model.baseEthereum == address
            }
        }) else {
            return nil
        }

        return metaAccounts.first(where: { $0.metaId == targetWallet.metaId })
    }

    private func select(wallet: MetaAccountModel, completion: @escaping (Error?) -> Void) {
        settings.save(value: wallet, runningCompletionIn: workingQueue) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: SelectedWalletSwitched())
                completion(nil)
            case let .failure(error):
                completion(error)
            }
        }
    }

    private func handleParsedMessage(
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
}

extension AssetDetailsNotificationMessageHandler {
    struct ResolvedParameters {
        let chainId: ChainModel.Id
        let assetId: String?
        let address: AccountAddress?
    }
}
