import Foundation
import RobinHood
import BigInt
import SubstrateSdk

protocol EquillibriumAssetsBalanceUpdaterProtocol {
    func handleReservedBalance(value: Data?, assetId: EquilibriumAssetId, blockHash: Data?)
    func handleAccountBalances(value: Data?, blockHash: Data?)
}

final class EquillibriumAssetsBalanceUpdater {
    let chainModel: ChainModel
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<AssetBalance>
    let transactionSubscription: TransactionSubscription?
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var lastReservedBalanceValue: [EquilibriumAssetId: Data?] = [:]
    private var receivedReservedBalance: [EquilibriumAssetId: Bool] = [:]

    private var lastAccountBalancesValue: Data?
    private var receivedAccountBalanaces: Bool = false

    private lazy var assetsMapping = createAssetsMapping(for: chainModel)
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)
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

    private func checkChanges(
        chainModel: ChainModel,
        accountId: AccountId,
        blockHash: Data?,
        logger: LoggerProtocol
    ) {
        guard receivedAccountBalanaces, !receivedReservedBalance.isEmpty else {
            return
        }

        logger.debug("Handle changes in balance")
        let accountBalancesPath = StorageCodingPath.equilibriumBalances
        let accountBalancesWrapper: CompoundOperationWrapper<EquilibriumAccountInfo?> =
            CommonOperationWrapper.storageDecoderWrapper(
                for: lastAccountBalancesValue,
                path: accountBalancesPath,
                chainModelId: chainModel.chainId,
                chainRegistry: chainRegistry
            )

        let changesWrapper = createChangesOperationWrapper(
            accountBalancesWrapper: accountBalancesWrapper,
            chainModel: chainModel,
            accountId: accountId
        )

        let saveOperation = repository.saveOperation({
            let changes = try changesWrapper.targetOperation.extractNoCancellableResultData()
            let changedItems = changes?.compactMap(\.item) ?? []

            logger.debug("Update \(changedItems.count) items")
            return changedItems
        }, {
            let changes = try changesWrapper.targetOperation.extractNoCancellableResultData()

            let deletingItems = changes?.compactMap {
                $0.isDeletion ? $0.identifier : nil
            } ?? []
            logger.debug("Delete \(deletingItems.count) items")
            return deletingItems
        })

        saveOperation.addDependency(changesWrapper.targetOperation)
        changesWrapper.addDependency(wrapper: accountBalancesWrapper)

        saveOperation.completionBlock = { [weak self] in
            self?.sendBalanceChangeEvents(changesWrapper: changesWrapper, blockHash: blockHash)
        }

        let operations = accountBalancesWrapper.allOperations +
            changesWrapper.allOperations + [saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func sendBalanceChangeEvents(
        changesWrapper: CompoundOperationWrapper<[DataProviderChange<AssetBalance>]?>,
        blockHash: Data?
    ) {
        DispatchQueue.global().async {
            guard let items = try? changesWrapper.targetOperation.extractNoCancellableResultData() else {
                return
            }

            items
                .compactMap(\.item)
                .forEach {
                    let assetBalanceChangeEvent = AssetBalanceChanged(
                        chainAssetId: $0.chainAssetId,
                        accountId: self.accountId,
                        changes: nil,
                        block: blockHash
                    )
                    self.eventCenter.notify(with: assetBalanceChangeEvent)

                    if let utilityChainAssetId = self.chainModel.utilityChainAssetId(),
                       utilityChainAssetId == $0.chainAssetId {
                        self.handleTransactionIfNeeded(for: blockHash)
                    }
                }
        }
    }

    private func createReservedBalanceWrapper(data: [Data?]) -> CompoundOperationWrapper<[EquilibriumReservedData?]> {
        let reservedBalancePath = StorageCodingPath.equilibriumReserved
        let reservedBalanceWrapper: CompoundOperationWrapper<[EquilibriumReservedData?]> =
            CommonOperationWrapper.storageDecoderListWrapper(
                for: data,
                path: reservedBalancePath,
                chainModelId: chainModel.chainId,
                chainRegistry: chainRegistry
            )
        return reservedBalanceWrapper
    }

    private func createChangesOperationWrapper(
        accountBalancesWrapper: CompoundOperationWrapper<EquilibriumAccountInfo?>,
        chainModel: ChainModel,
        accountId: AccountId
    ) -> CompoundOperationWrapper<[DataProviderChange<AssetBalance>]?> {
        OperationCombiningService.compoundWrapper(operationManager: operationManager) {
            let accountBalances = try accountBalancesWrapper.targetOperation.extractNoCancellableResultData()
            let fetchOperation = self.repository.fetchAllOperation(with: .none)
            let accountBalancesWithReservedData = accountBalances?.balances.filter {
                self.receivedReservedBalance[$0.asset] == true
            } ?? []
            let data = accountBalancesWithReservedData.map {
                self.lastReservedBalanceValue[$0.asset] ?? nil
            }
            let reservedBalancesWrapper = self.createReservedBalanceWrapper(data: data)
            let changesOperation = ClosureOperation<[DataProviderChange<AssetBalance>]> {
                let reservedBalance = try reservedBalancesWrapper.targetOperation.extractNoCancellableResultData()
                let localModels = try fetchOperation.extractNoCancellableResultData()
                let utilityAsset = chainModel.utilityAsset()?.assetId
                let lock = accountBalances?.lock ?? .zero

                let mappedBalances = accountBalancesWithReservedData.enumerated().reduce(into: [AssetModel.Id: AssetBalance]()) { result, balance in
                    guard let assetId = self.assetsMapping[balance.element.asset] else {
                        return
                    }
                    let frozenInPlank = assetId == utilityAsset ? lock : .zero
                    let reservedInPlank = reservedBalance[balance.offset]?.value ?? .zero
                    let freeInPlank = balance.element.balance.value

                    result[assetId] = AssetBalance(
                        chainAssetId: .init(chainId: chainModel.chainId, assetId: assetId),
                        accountId: accountId,
                        freeInPlank: freeInPlank,
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

            changesOperation.addDependency(reservedBalancesWrapper.targetOperation)
            changesOperation.addDependency(fetchOperation)

            return CompoundOperationWrapper(
                targetOperation: changesOperation,
                dependencies:
                reservedBalancesWrapper.allOperations + [fetchOperation]
            )
        }
    }

    private func handleTransactionIfNeeded(for blockHash: Data?) {
        guard let blockHash = blockHash else {
            return
        }

        logger.debug("Handle equilibrium change transactions")
        transactionSubscription?.process(blockHash: blockHash)
    }
}

extension EquillibriumAssetsBalanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol {
    func handleReservedBalance(value: Data?, assetId: EquilibriumAssetId, blockHash: Data?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        receivedReservedBalance[assetId] = true
        lastReservedBalanceValue[assetId] = value

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
}
