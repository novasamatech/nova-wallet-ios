import Foundation
import Operation_iOS

struct SubtensorShieldFunds {
    let transferable: Balance
    let existentialDeposit: Balance
}

protocol SubtensorShieldFundsFactoryProtocol {
    func createFundsWrapper() -> CompoundOperationWrapper<SubtensorShieldFunds>
}

final class SubtensorShieldFundsFactory {
    let accountId: AccountId
    let chainAsset: ChainAsset
    let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.balanceQueryFactory = balanceQueryFactory
        self.runtimeProvider = runtimeProvider
    }
}

extension SubtensorShieldFundsFactory: SubtensorShieldFundsFactoryProtocol {
    func createFundsWrapper() -> CompoundOperationWrapper<SubtensorShieldFunds> {
        let balanceWrapper = balanceQueryFactory.queryBalance(for: accountId, chainAsset: chainAsset)

        let depositWrapper = PrimitiveConstantOperation<Balance>.wrapper(
            for: .existentialDeposit,
            runtimeService: runtimeProvider
        )

        let fundsOperation = ClosureOperation<SubtensorShieldFunds> {
            SubtensorShieldFunds(
                transferable: try balanceWrapper.targetOperation.extractNoCancellableResultData().transferable,
                existentialDeposit: try depositWrapper.targetOperation.extractNoCancellableResultData()
            )
        }

        fundsOperation.addDependency(balanceWrapper.targetOperation)
        fundsOperation.addDependency(depositWrapper.targetOperation)

        return balanceWrapper
            .insertingHead(operations: depositWrapper.allOperations)
            .insertingTail(operation: fundsOperation)
    }
}
