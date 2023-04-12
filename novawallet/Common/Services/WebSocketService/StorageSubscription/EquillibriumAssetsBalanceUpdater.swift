import Foundation
import RobinHood
import BigInt
import SubstrateSdk

protocol EquillibriumAssetsBalanceUpdaterProtocol {
    func handleReservedBalance(value: Data?, blockHash: Data?)
    func handleAssetAccount(value: Data?, blockHash: Data?)
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

    private var lastReservedValue: Data?
    private var receivedReserved: Bool = false

    private var lastAccountValue: Data?
    private var receivedAccount: Bool = false
    private var lastAccountValueHash: Data?
    private let assetsMapping: [AssetModel.Id: AssetModel.Id]

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
        assetsMapping = Self.createAssetsMapping(for: chainModel)
    }

    private static func createAssetsMapping(for chainModel: ChainModel) -> [AssetModel.Id: AssetModel.Id] {
        chainModel.equilibriumAssets.reduce(into: [AssetModel.Id: AssetModel.Id]()) {
            if let extras = try? $1.typeExtras?.map(to: StatemineAssetExtras.self),
               let key = AssetModel.Id(extras.assetId) {
                $0[key] = $1.assetId
            }
        }
    }

    func handleReservedBalance(value: Data?, blockHash: Data?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        receivedReserved = true
        lastReservedValue = value

        checkChanges(
            chainModel: chainModel,
            accountId: accountId,
            blockHash: blockHash,
            logger: logger
        )
    }

    func handleAssetAccount(value: Data?, blockHash: Data?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        receivedAccount = true
        lastAccountValue = value

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
        guard receivedAccount, receivedReserved else {
            return
        }

        let assetsAccountPath = StorageCodingPath.equilibriumBalances
        let assetsAccountWrapper: CompoundOperationWrapper<EquilibriumAccountInfo?> =
            createStorageDecoderWrapper(for: lastAccountValue, path: assetsAccountPath)

        let reservedBalancePath = StorageCodingPath.equilibriumReserved
        let reservedBalanceWrapper: CompoundOperationWrapper<EquilibriumReservedData?> =
            createStorageDecoderWrapper(for: lastReservedValue, path: reservedBalancePath)

        let changesWrapper = createChangesOperationWrapper(
            reservedBalanceWrapper: reservedBalanceWrapper,
            accountWrapper: assetsAccountWrapper,
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
        changesWrapper.addDependency(wrapper: assetsAccountWrapper)
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
                    }
            }
        }

        let operations = reservedBalanceWrapper.allOperations + assetsAccountWrapper.allOperations +
            changesWrapper.allOperations + [saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func createChangesOperationWrapper(
        reservedBalanceWrapper: CompoundOperationWrapper<EquilibriumReservedData?>,
        accountWrapper: CompoundOperationWrapper<EquilibriumAccountInfo?>,
        chainModel: ChainModel,
        accountId: AccountId
    ) -> CompoundOperationWrapper<[DataProviderChange<AssetBalance>]> {
        let fetchOperation = repository.fetchAllOperation(with: .none)

        let changesOperation = ClosureOperation<[DataProviderChange<AssetBalance>]> {
            let assetsAccount = try accountWrapper.targetOperation.extractNoCancellableResultData()
            let reservedBalance = try reservedBalanceWrapper.targetOperation.extractNoCancellableResultData()?.value ?? .zero
            let localModels = try fetchOperation.extractNoCancellableResultData()

            let utilityAsset = chainModel.utilityAsset()?.assetId
            let balances = assetsAccount?.balances {
                self.assetsMapping[$0]
            } ?? [:]
            let lock = assetsAccount?.lock ?? .zero
            let mappedBalances = balances.reduce(into: [AssetModel.Id: AssetBalance]()) {
                let assetId = $1.key
                let frozenInPlank = assetId == utilityAsset ? lock : .zero
                let reservedInPlank = assetId == utilityAsset ? reservedBalance : .zero

                $0[assetId] = AssetBalance(
                    chainAssetId: .init(chainId: chainModel.chainId, assetId: assetId),
                    accountId: accountId,
                    freeInPlank: $1.value,
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

    private func createStorageDecoderWrapper<T: Decodable>(
        for value: Data?,
        path: StorageCodingPath
    ) -> CompoundOperationWrapper<T?> {
        guard let storageData = value else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainModel.chainId) else {
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

    private func handleTransactionIfNeeded(for blockHash: Data?) {
        if let blockHash = blockHash {
            logger.debug("Handle statemine change transactions")
            // transactionSubscription?.process(blockHash: blockHash)
        }
    }
}

struct EquilibriumAccountInfo: Decodable {
    @StringCodable var nonce: UInt32
    let data: EquilibriumAccountData

    func balances<TKey>(mapKey: (AssetModel.Id) -> TKey?) -> [TKey: BigUInt] where TKey: Hashable {
        switch data {
        case let .v0(_, balances):
            return balances.reduce(into: [TKey: BigUInt]()) {
                if let key = mapKey($1.asset) {
                    switch $1.balance {
                    case let .positive(value):
                        $0[key] = value
                    case .negative:
                        $0[key] = BigUInt.zero
                    }
                }
            }
        }
    }

    var lock: BigUInt? {
        switch data {
        case let .v0(lock, _):
            return lock
        }
    }
}

enum EquilibriumAccountData: Decodable {
    case v0(lock: BigUInt?, balance: [EquilibriumRemoteBalance])

    enum CodingKeys: CodingKey {
        case lock
        case balance
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type.lowercased() {
        case "v0":
            let version = try container.decode(V0.self)
            self = .v0(lock: version.lock, balance: version.balance)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected asset status"
            )
        }
    }
}

struct V0: Decodable {
    let lock: BigUInt?
    let balance: [EquilibriumRemoteBalance]

    enum CodingKeys: CodingKey {
        case lock
        case balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lock = try container.decodeIfPresent(StringScaleMapper<BigUInt>.self, forKey: .lock)?.value
        balance = try container.decode([EquilibriumRemoteBalance].self, forKey: .balance)
    }
}

struct EquilibriumRemoteBalance: Decodable {
    var asset: UInt32
    let balance: SignedBalance

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let asset = try container.decode(StringScaleMapper<UInt32>.self).value
        let balance = try container.decode(SignedBalance.self)
        self.asset = asset
        self.balance = balance
    }
}

enum SignedBalance: Codable {
    case positive(BigUInt)
    case negative(BigUInt)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type.lowercased() {
        case "positive":
            let balance = try container.decode(StringScaleMapper<BigUInt>.self).value
            self = .positive(balance)
        case "negative":
            let balance = try container.decode(StringScaleMapper<BigUInt>.self).value
            self = .negative(balance)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected asset status"
            )
        }
    }
}

struct EquilibriumReservedData: Codable {
    @StringCodable var value: BigUInt
}

// enum EquilibriumAccountData: Decodable {
//    case v0(lock: BigUInt?, balances: [EquilibriumRemoteBalance])
//
//    init(from decoder: Decoder) throws {
//        let dddd = try decoder.unkeyedContainer()
//        self = .v0(lock: nil, balances: [])
//    }
//
//    func balances<TKey>(mapKey: (AssetModel.Id) -> TKey?) -> [TKey: BigUInt] where TKey: Hashable {
//        switch self {
//        case let .v0(_, balances):
//            return balances.reduce(into: [TKey: BigUInt]()) {
//                if let key = mapKey($1.asset) {
//                    switch $1.balance {
//                    case let .positive(value):
//                        $0[key] = value
//                    case .negative:
//                        $0[key] = BigUInt.zero
//                    }
//                }
//            }
//        }
//    }
//
//    var lock: BigUInt? {
//        switch self {
//        case let .v0(lock, _):
//            return lock
//        }
//    }
// }
//
// struct EquilibriumRemoteBalance: Decodable {
//    let asset: UInt32
//    let balance: SignedBalance<BigUInt>
// }
//
// enum SignedBalance<Balance>: Codable where Balance: Codable {
//    case positive(Balance)
//    case negative(Balance)
// }
//
// struct EquilibriumReservedData: Codable {
//    @StringCodable var value: BigUInt
// }
