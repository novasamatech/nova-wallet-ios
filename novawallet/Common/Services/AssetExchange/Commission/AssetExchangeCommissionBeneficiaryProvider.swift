import Foundation
import Operation_iOS

struct CommissionBeneficiaryState {
    let chainAsset: ChainAsset
    let balance: Balance
    let existentialDeposit: Balance

    var canReceive: Bool {
        balance > existentialDeposit
    }
}

protocol AssetExchangeCommissionBeneficiaryProviding {
    func fetchStateWrapper(for chainAsset: ChainAsset) -> CompoundOperationWrapper<CommissionBeneficiaryState>
}

final class AssetExchangeCommissionBeneficiaryProvider {
    let beneficiary: AccountId
    let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private let mutex = NSLock()
    private var cache: [ChainAssetId: CommissionBeneficiaryState] = [:]

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
    func cachedState(for chainAssetId: ChainAssetId) -> CommissionBeneficiaryState? {
        mutex.lock()
        defer { mutex.unlock() }

        return cache[chainAssetId]
    }

    func store(_ state: CommissionBeneficiaryState) {
        mutex.lock()
        defer { mutex.unlock() }

        cache[state.chainAsset.chainAssetId] = state
    }
}

extension AssetExchangeCommissionBeneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding {
    func fetchStateWrapper(for chainAsset: ChainAsset) -> CompoundOperationWrapper<CommissionBeneficiaryState> {
        if let cached = cachedState(for: chainAsset.chainAssetId) {
            return .createWithResult(cached)
        }

        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            let existenceWrapper = assetStorageInfoFactory.createAssetBalanceExistenceOperation(
                chainId: chainAsset.chain.chainId,
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
                    chainAsset: chainAsset,
                    balance: balance.balanceCountingEd,
                    existentialDeposit: existence.minBalance
                )

                self.store(state)

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
