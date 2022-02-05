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

    private var lastDetailsValue: ChainStorageItem?
    private var receivedDetails: Bool = false

    private var lastAccountValue: ChainStorageItem?
    private var receivedAccount: Bool = false

    private var hasChanges: Bool = false

    private let mutex = NSLock()

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

    func handleAssetDetails(value: ChainStorageItem?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        hasChanges = hasChanges || (value != nil) || (!receivedDetails)
        receivedDetails = true

        if value != nil {
            lastDetailsValue = value
        }

        checkChanges(chainAssetId: chainAssetId, accountId: accountId)
    }

    func handleAssetAccount(value: ChainStorageItem?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        hasChanges = hasChanges || (value != nil) || (!receivedAccount)
        receivedAccount = true

        if value != nil {
            lastAccountValue = value
        }

        checkChanges(chainAssetId: chainAssetId, accountId: accountId)
    }

    private func checkChanges(chainAssetId: ChainAssetId, accountId: AccountId) {
        if hasChanges, receivedAccount, receivedDetails {
            hasChanges = false

            let assetAccountWrapper: CompoundOperationWrapper<AssetAccount?> =
                createStorageDecoderWrapper(for: lastAccountValue, path: .assetsAccount)

            let assetDetailsWrapper: CompoundOperationWrapper<AssetDetails?> =
                createStorageDecoderWrapper(for: lastDetailsValue, path: .assetsDetails)

            let changesWrapper = createChangesOperationWrapper(
                dependingOn: assetDetailsWrapper,
                accountWrapper: assetAccountWrapper,
                chainAssetId: chainAssetId,
                accountId: accountId
            )

            let saveOperation = assetRepository.saveOperation({
                let change = try changesWrapper.targetOperation.extractNoCancellableResultData()

                if let remoteModel = change?.item {
                    return [remoteModel]
                } else {
                    return []
                }
            }, {
                let change = try changesWrapper.targetOperation.extractNoCancellableResultData()

                if case let .delete(identifier) = change {
                    return [identifier]
                } else {
                    return []
                }
            })

            changesWrapper.addDependency(wrapper: assetAccountWrapper)
            changesWrapper.addDependency(wrapper: assetDetailsWrapper)
            saveOperation.addDependency(changesWrapper.targetOperation)

            saveOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    let maybeItem = try? changesWrapper.targetOperation.extractNoCancellableResultData()

                    if maybeItem != nil {
                        self?.eventCenter.notify(with: WalletBalanceChanged())
                    }
                }
            }

            let operations = assetDetailsWrapper.allOperations + assetAccountWrapper.allOperations +
                changesWrapper.allOperations + [saveOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)
        }
    }

    private func createChangesOperationWrapper(
        dependingOn detailsWrapper: CompoundOperationWrapper<AssetDetails?>,
        accountWrapper: CompoundOperationWrapper<AssetAccount?>,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) -> CompoundOperationWrapper<DataProviderChange<AssetBalance>?> {
        let identifier = AssetBalance.createIdentifier(for: chainAssetId, accountId: accountId)
        let fetchOperation = assetRepository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let changesOperation = ClosureOperation<DataProviderChange<AssetBalance>?> {
            let assetAccount = try accountWrapper.targetOperation.extractNoCancellableResultData()
            let localModel = try fetchOperation.extractNoCancellableResultData()

            let balance = assetAccount?.balance ?? 0

            let assetDetails = try detailsWrapper.targetOperation.extractNoCancellableResultData()

            let isFrozen = (assetAccount?.isFrozen ?? false) || (assetDetails?.isFrozen ?? false)

            let remoteModel = AssetBalance(
                chainAssetId: chainAssetId,
                accountId: accountId,
                freeInPlank: balance,
                reservedInPlank: 0,
                frozenInPlank: isFrozen ? balance : 0
            )

            if localModel != remoteModel, balance > 0 {
                return DataProviderChange.update(newItem: remoteModel)
            } else if localModel != nil, balance == 0 {
                return DataProviderChange.delete(deletedIdentifier: identifier)
            } else {
                return nil
            }
        }

        changesOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: changesOperation, dependencies: [fetchOperation])
    }

    private func createStorageDecoderWrapper<T: Decodable>(
        for value: ChainStorageItem?,
        path: StorageCodingPath
    ) -> CompoundOperationWrapper<T?> {
        guard let storageData = value?.data else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let decodingOperation = StorageDecodingOperation<T>(path: path, data: storageData)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<T?> {
            try decodingOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, decodingOperation]
        )
    }
}
