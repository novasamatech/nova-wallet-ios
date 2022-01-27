import Foundation
import RobinHood

final class OrmlAccountSubscription: BaseStorageChildSubscription {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let assetRepository: AnyDataProviderRepository<AssetBalance>
    let eventCenter: EventCenterProtocol

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        assetRepository: AnyDataProviderRepository<AssetBalance>,
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.assetRepository = assetRepository
        self.eventCenter = eventCenter

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    override func handle(
        result _: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem: ChainStorageItem?,
        blockHash _: Data?
    ) {
        logger.debug("Did orml account update")

        decodeAndSaveAccountInfo(
            remoteItem,
            chainAssetId: chainAssetId,
            accountId: accountId
        )
    }

    private func decodeAndSaveAccountInfo(
        _ item: ChainStorageItem?,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let decodingOperation = StorageFallbackDecodingOperation<OrmlAccount>(
            path: .ormlTokenAccount,
            data: item?.data
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let identifier = AssetBalance.createIdentifier(for: chainAssetId, accountId: accountId)
        let fetchOperation = assetRepository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let saveOperation = assetRepository.saveOperation({
            let account = try decodingOperation.extractNoCancellableResultData()
            let localModel = try fetchOperation.extractNoCancellableResultData()

            let remoteModel = AssetBalance(
                chainAssetId: chainAssetId,
                accountId: accountId,
                freeInPlank: account?.free ?? 0,
                reservedInPlank: account?.reserved ?? 0,
                frozenInPlank: account?.frozen ?? 0
            )

            Logger.shared.info("Apply model: \(remoteModel)")

            if localModel != remoteModel, remoteModel.totalInPlank > 0 {
                return [remoteModel]
            } else {
                return []
            }
        }, {
            let account = try decodingOperation.extractNoCancellableResultData()
            let localModel = try fetchOperation.extractNoCancellableResultData()

            let total = account?.total ?? 0

            if total == 0, localModel != nil {
                return [identifier]
            } else {
                return []
            }
        })

        saveOperation.addDependency(fetchOperation)
        saveOperation.addDependency(decodingOperation)

        saveOperation.completionBlock = {
            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletBalanceChanged())
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation, fetchOperation, saveOperation],
            in: .transient
        )
    }
}
