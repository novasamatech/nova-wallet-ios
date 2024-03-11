import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

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
        for chainId: ChainModel.Id,
        assetId: String?,
        address: AccountAddress?,
        completion: @escaping (Result<ChainAssetId, AssetDetailsHandlingError>) -> Void
    ) {
        guard let address = address else {
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

            guard let chainModel = chains.first(where: { $0.chainId == chainId }) else {
                return
            }

            self.chainRegistry.chainsUnsubscribe(self)

            self.handle(
                chain: chainModel,
                assetId: assetId,
                address: address,
                completion: completion
            )
        }
    }

    private func handle(
        chain: ChainModel,
        assetId: String?,
        address: AccountAddress,
        completion: @escaping (Result<ChainAssetId, AssetDetailsHandlingError>) -> Void
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
                wallets: wallets,
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
        ) { result in
            switch result {
            case let .success(result):
                guard let wallet = result else {
                    completion(.failure(AssetDetailsHandlingError.unknownWallet))
                    return
                }

                self.select(wallet: wallet) { error in
                    if let error = error {
                        completion(.failure(AssetDetailsHandlingError.select(error)))
                    } else {
                        completion(.success(ChainAssetId(
                            chainId: chain.chainId,
                            assetId: asset.assetId
                        )))
                    }
                }

            case let .failure(error):
                completion(.failure(AssetDetailsHandlingError.select(error)))
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
        wallets: [Web3Alert.LocalWallet],
        metaAccounts: [MetaAccountModel]
    ) -> MetaAccountModel? {
        guard let targetWallet = wallets.first(where: {
            if let specificAddress = $0.remoteModel.chainSpecific[chainId] {
                return specificAddress == address
            } else {
                return $0.remoteModel.baseSubstrate == address ||
                    $0.remoteModel.baseEthereum == address
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
                self?.eventCenter.notify(with: SelectedAccountChanged())
                completion(nil)
            case let .failure(error):
                completion(error)
            }
        }
    }
}

extension AssetDetailsNotificationMessageHandler: NotificationMessageHandlerProtocol {
    func handle(message: NotificationMessage, completion: @escaping (Result<PushHandlingScreen, Error>) -> Void) {
        let targetAddress: AccountAddress?
        let targetChainId: ChainModel.Id
        let targetAssetId: String?

        switch message {
        case let .stakingReward(chainId, payload):
            targetChainId = chainId
            targetAddress = payload.recipient
            targetAssetId = nil
        case let .transfer(type, chainId, payload):
            switch type {
            case .income:
                targetAddress = payload.recipient
                targetAssetId = payload.assetId
            case .outcome:
                targetAddress = payload.sender
                targetAssetId = payload.assetId
            }
            targetChainId = chainId
        default:
            completion(.failure(AssetDetailsHandlingError.internalError))
            return
        }

        handle(
            for: targetChainId,
            assetId: targetAssetId,
            address: targetAddress
        ) {
            switch $0 {
            case let .success(chainAssetId):
                completion(.success(.historyDetails(chainAssetId)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}
