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

                if localModel != remoteModel, balance > 0 {
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
