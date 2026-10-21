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

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let depositOperation = PrimitiveConstantOperation<Balance>(path: .existentialDeposit)

        depositOperation.configurationBlock = {
            do {
                depositOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                depositOperation.result = .failure(error)
            }
        }

        depositOperation.addDependency(codingFactoryOperation)

        let fundsOperation = ClosureOperation<SubtensorShieldFunds> {
            SubtensorShieldFunds(
                transferable: try balanceWrapper.targetOperation.extractNoCancellableResultData().transferable,
                existentialDeposit: try depositOperation.extractNoCancellableResultData()
            )
        }

        fundsOperation.addDependency(balanceWrapper.targetOperation)
        fundsOperation.addDependency(depositOperation)

        return balanceWrapper
            .insertingHead(operations: [codingFactoryOperation, depositOperation])
            .insertingTail(operation: fundsOperation)
    }
}
