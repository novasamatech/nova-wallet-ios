import Foundation
import RobinHood

final class AssetsBalanceUpdater {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let assetRepository: AnyDataProviderRepository<AssetBalance>
    let chainRepository: AnyDataProviderRepository<ChainStorageItem>
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    private var assetDetailsKey: String?
    private var assetAccountKey: String?
    private var hasChanges: Bool = false

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        assetRepository: AnyDataProviderRepository<AssetBalance>,
        chainRepository: AnyDataProviderRepository<ChainStorageItem>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.assetRepository = assetRepository
        self.chainRepository = chainRepository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }

    func handleAssetDetails(change: DataProviderChange<ChainStorageItem>?, localKey: String) {
        hasChanges = hasChanges || (change != nil) || (assetDetailsKey == nil)
        assetDetailsKey = localKey

        checkChanges(chainAssetId: chainAssetId, accountId: accountId)
    }

    func handleAssetAccount(change: DataProviderChange<ChainStorageItem>?, localKey: String) {
        hasChanges = hasChanges || (change != nil) || (assetAccountKey == nil)
        assetAccountKey = localKey

        checkChanges(chainAssetId: chainAssetId, accountId: accountId)
    }

    private func checkChanges(chainAssetId: ChainAssetId, accountId: AccountId) {
        if hasChanges, let assetDetailsKey = assetDetailsKey, let assetAccountKey = assetAccountKey {
            hasChanges = false

            let assetAccountWrapper: CompoundOperationWrapper<AssetAccount?> =
                createFetchStorageItemWrapper(for: assetAccountKey, path: .assetsAccount)

            let assetDetailsWrapper: CompoundOperationWrapper<AssetDetails?> =
                createFetchStorageItemWrapper(for: assetDetailsKey, path: .assetsDetails)

            let identifier = AssetBalance.createIdentifier(for: chainAssetId, accountId: accountId)
            let fetchOperation = assetRepository.fetchOperation(
                by: identifier,
                options: RepositoryFetchOptions()
            )

            let saveOperation = assetRepository.saveOperation({
                let assetAccount = try assetAccountWrapper.targetOperation.extractNoCancellableResultData()
                let localModel = try fetchOperation.extractNoCancellableResultData()

                let balance = assetAccount?.balance ?? 0

                let assetDetails = try assetDetailsWrapper.targetOperation.extractNoCancellableResultData()

                let isFrozen = (assetAccount?.isFrozen ?? false) || (assetDetails?.isFrozen ?? false)

                let remoteModel = AssetBalance(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    freeInPlank: !isFrozen ? balance : 0,
                    reservedInPlank: 0,
                    frozenInPlank: isFrozen ? balance : 0
                )

                if localModel != remoteModel {
                    return [remoteModel]
                } else {
                    return []
                }
            }, {
                let assetAccount = try assetAccountWrapper.targetOperation.extractNoCancellableResultData()
                let localModel = try fetchOperation.extractNoCancellableResultData()

                let balance = assetAccount?.balance ?? 0

                if balance == 0, localModel != nil {
                    return [identifier]
                } else {
                    return []
                }
            })

            saveOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    self?.eventCenter.notify(with: WalletBalanceChanged())
                }
            }

            let dependencies = [fetchOperation] + assetDetailsWrapper.allOperations +
                assetAccountWrapper.allOperations
            dependencies.forEach { saveOperation.addDependency($0) }

            let operations = dependencies + [saveOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)
        }
    }

    private func createFetchStorageItemWrapper<T: Decodable>(
        for localKey: String,
        path: StorageCodingPath
    ) -> CompoundOperationWrapper<T?> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchOperation = chainRepository.fetchOperation(
            by: localKey,
            options: RepositoryFetchOptions()
        )

        let decodingOperation = StorageFallbackDecodingOperation<T>(path: path)
        decodingOperation.configurationBlock = {
            do {
                let maybeItem = try fetchOperation.extractNoCancellableResultData()
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()

                if let item = maybeItem {
                    decodingOperation.data = item.data
                } else {
                    decodingOperation.result = .success(nil)
                }
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)
        decodingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [codingFactoryOperation, fetchOperation]
        )
    }
}
