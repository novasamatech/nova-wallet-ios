import Foundation
import Operation_iOS

struct CommissionBeneficiaryState {
    let balance: Balance
    let existentialDeposit: Balance

    var canReceive: Bool {
        balance >= existentialDeposit
    }
}

protocol AssetExchangeCommissionBeneficiaryProviding {
    func fetchStateWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<CommissionBeneficiaryState>
}

final class AssetExchangeCommissionBeneficiaryProvider {
    let beneficiary: AccountId
    let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private let mutex = NSLock()
    private var cache: [ChainModel.Id: CommissionBeneficiaryState] = [:]

    init(
        beneficiary: AccountId,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.beneficiary = beneficiary
        self.balanceQueryFactory = balanceQueryFactory
        self.assetStorageInfoFactory = assetStorageInfoFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

private extension AssetExchangeCommissionBeneficiaryProvider {
    func cachedState(for chainId: ChainModel.Id) -> CommissionBeneficiaryState? {
        mutex.lock()
        defer { mutex.unlock() }

        return cache[chainId]
    }

    func store(_ state: CommissionBeneficiaryState, for chainId: ChainModel.Id) {
        mutex.lock()
        defer { mutex.unlock() }

        cache[chainId] = state
    }

    func utilityChainAsset(for chainId: ChainModel.Id) throws -> ChainAsset {
        let chain = try chainRegistry.getChainOrError(for: chainId)

        guard let chainAsset = chain.utilityChainAsset() else {
            throw ChainModelFetchError.noAsset(assetId: AssetModel.utilityAssetId)
        }

        return chainAsset
    }
}

extension AssetExchangeCommissionBeneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding {
    func fetchStateWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<CommissionBeneficiaryState> {
        if let cached = cachedState(for: chainId) {
            return .createWithResult(cached)
        }

        do {
            let chainAsset = try utilityChainAsset(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let existenceWrapper = assetStorageInfoFactory.createAssetBalanceExistenceOperation(
                chainId: chainId,
                asset: chainAsset.asset,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue
            )

            let balanceWrapper = balanceQueryFactory.queryBalance(
                for: beneficiary,
                chainAsset: chainAsset
            )

            let mergeOperation = ClosureOperation<CommissionBeneficiaryState> {
                let existence = try existenceWrapper.targetOperation.extractNoCancellableResultData()
                let balance = try balanceWrapper.targetOperation.extractNoCancellableResultData()

                let state = CommissionBeneficiaryState(
                    balance: balance.balanceCountingEd,
                    existentialDeposit: existence.minBalance
                )

                self.store(state, for: chainId)

                return state
            }

            mergeOperation.addDependency(existenceWrapper.targetOperation)
            mergeOperation.addDependency(balanceWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: existenceWrapper.allOperations + balanceWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }
}
