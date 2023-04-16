import Foundation
import RobinHood
import BigInt
import SubstrateSdk

protocol EquillibriumAssetsBalanceUpdaterProtocol {
    func handleReservedBalance(value: Data?, blockHash: Data?)
    func handleAccountBalances(value: Data?, blockHash: Data?)
}

final class EquillibriumAssetsBalanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol {
    let chainModel: ChainModel
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<AssetBalance>
    let transactionSubscription: TransactionSubscription?
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var lastReservedBalalnceValue: Data?
    private var receivedReservedBalance: Bool = false

    private var lastAccountBalancesValue: Data?
    private var receivedAccountBalanaces: Bool = false

    private lazy var assetsMapping = createAssetsMapping(for: chainModel)

    private let mutex = NSLock()

    init(
        chainModel: ChainModel,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetBalance>,
        transactionSubscription: TransactionSubscription?,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainModel = chainModel
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.transactionSubscription = transactionSubscription
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.logger = logger
    }

    private func createAssetsMapping(for chainModel: ChainModel) -> [EquilibriumAssetId: AssetModel.Id] {
        chainModel.equilibriumAssets.reduce(into: [UInt64: AssetModel.Id]()) {
            if let equilibriumAssetId = $1.equilibriumAssetId {
                $0[equilibriumAssetId] = $1.assetId
            }
        }
    }

    func handleReservedBalance(value: Data?, blockHash: Data?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        receivedReservedBalance = true
        lastReservedBalalnceValue = value

        checkChanges(
            chainModel: chainModel,
            accountId: accountId,
            blockHash: blockHash,
            logger: logger
        )
    }

    func handleAccountBalances(value: Data?, blockHash: Data?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        receivedAccountBalanaces = true
        lastAccountBalancesValue = value

        checkChanges(
            chainModel: chainModel,
            accountId: accountId,
            blockHash: blockHash,
            logger: logger
        )
    }

    private func checkChanges(
        chainModel: ChainModel,
        accountId: AccountId,
        blockHash: Data?,
        logger _: LoggerProtocol
    ) {
        guard receivedAccountBalanaces, receivedReservedBalance else {
            return
        }

        let accountBalancesPath = StorageCodingPath.equilibriumBalances
        let accountBalancesWrapper: CompoundOperationWrapper<EquilibriumAccountInfo?> =
            CommonOperationWrapper.storageDecoderWrapper(
                for: lastAccountBalancesValue,
                path: accountBalancesPath,
                chainModelId: chainModel.chainId,
                chainRegistry: chainRegistry
            )

        let reservedBalancePath = StorageCodingPath.equilibriumReserved
        let reservedBalanceWrapper: CompoundOperationWrapper<EquilibriumReservedData?> =
            CommonOperationWrapper.storageDecoderWrapper(
                for: lastReservedBalalnceValue,
                path: reservedBalancePath,
                chainModelId: chainModel.chainId,
                chainRegistry: chainRegistry
            )

        let changesWrapper = createChangesOperationWrapper(
            reservedBalanceWrapper: reservedBalanceWrapper,
            accountBalancesWrapper: accountBalancesWrapper,
            chainModel: chainModel,
            accountId: accountId
        )

        let saveOperation = repository.saveOperation({
            let changes = try changesWrapper.targetOperation.extractNoCancellableResultData()
            return changes.compactMap(\.item)
        }, {
            let changes = try changesWrapper.targetOperation.extractNoCancellableResultData()
            return changes.compactMap {
                $0.isDeletion ? $0.identifier : nil
            }
        })

        saveOperation.addDependency(changesWrapper.targetOperation)
        changesWrapper.addDependency(wrapper: accountBalancesWrapper)
        changesWrapper.addDependency(wrapper: reservedBalanceWrapper)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.global().async {
                guard let items = try? changesWrapper.targetOperation.extractNoCancellableResultData() else {
                    return
                }

                items
                    .compactMap(\.item)
                    .forEach {
                        let assetBalanceChangeEvent = AssetBalanceChanged(
                            chainAssetId: $0.chainAssetId,
                            accountId: accountId,
                            changes: nil,
                            block: blockHash
                        )
                        self?.eventCenter.notify(with: assetBalanceChangeEvent)

                        if let utilityChainAssetId = chainModel.utilityChainAssetId(),
                           utilityChainAssetId == $0.chainAssetId {
                            self?.handleTransactionIfNeeded(for: blockHash)
                        }
                    }
            }
        }

        let operations = reservedBalanceWrapper.allOperations + accountBalancesWrapper.allOperations +
            changesWrapper.allOperations + [saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func createChangesOperationWrapper(
        reservedBalanceWrapper: CompoundOperationWrapper<EquilibriumReservedData?>,
        accountBalancesWrapper: CompoundOperationWrapper<EquilibriumAccountInfo?>,
        chainModel: ChainModel,
        accountId: AccountId
    ) -> CompoundOperationWrapper<[DataProviderChange<AssetBalance>]> {
        let fetchOperation = repository.fetchAllOperation(with: .none)

        let changesOperation = ClosureOperation<[DataProviderChange<AssetBalance>]> {
            let accountBalances = try accountBalancesWrapper.targetOperation.extractNoCancellableResultData()
            let reservedBalance = try reservedBalanceWrapper.targetOperation.extractNoCancellableResultData()?.value ?? .zero
            let localModels = try fetchOperation.extractNoCancellableResultData()

            let utilityAsset = chainModel.utilityAsset()?.assetId
            let balances = accountBalances?.balances {
                self.assetsMapping[$0]
            } ?? [:]
            let lock = accountBalances?.lock ?? .zero

            let mappedBalances = balances.reduce(into: [AssetModel.Id: AssetBalance]()) { result, balance in
                let assetId = balance.key
                let frozenInPlank = assetId == utilityAsset ? lock : .zero
                let reservedInPlank = assetId == utilityAsset ? reservedBalance : .zero

                result[assetId] = AssetBalance(
                    chainAssetId: .init(chainId: chainModel.chainId, assetId: assetId),
                    accountId: accountId,
                    freeInPlank: balance.value,
                    reservedInPlank: reservedInPlank,
                    frozenInPlank: frozenInPlank
                )
            }
            let localModelsIds = localModels.map(\.chainAssetId)

            var changes: [DataProviderChange<AssetBalance>] = localModels.compactMap { localModel in
                if let remoteModel = mappedBalances[localModel.chainAssetId.assetId] {
                    if remoteModel != localModel {
                        return .update(newItem: remoteModel)
                    }
                } else {
                    return .delete(deletedIdentifier: localModel.identifier)
                }

                return nil
            }

            let newItems = mappedBalances.values.filter {
                !localModelsIds.contains($0.chainAssetId)
            }.map {
                DataProviderChange<AssetBalance>.insert(newItem: $0)
            }
            changes.append(contentsOf: newItems)

            return changes
        }

        changesOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: changesOperation, dependencies: [fetchOperation])
    }

    private func handleTransactionIfNeeded(for blockHash: Data?) {
        guard let blockHash = blockHash else {
            return
        }

        logger.debug("Handle equilibrium change transactions")
        transactionSubscription?.process(blockHash: blockHash)
    }
}
