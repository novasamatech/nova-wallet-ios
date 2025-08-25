import Foundation
import Operation_iOS

extension AnyDataProviderRepository where T == MetaAccountModel {
    func createWalletsWrapperByAccountId(
        for chainProvider: @escaping () throws -> ChainModel
    ) -> CompoundOperationWrapper<[AccountId: MetaChainAccountResponse]> {
        let allWalletsOperation = fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<[AccountId: MetaChainAccountResponse]> {
            let wallets = try allWalletsOperation.extractNoCancellableResultData()
            let chain = try chainProvider()

            let localDict = wallets.reduce(
                into: [AccountId: [MetaChainAccountResponse]]()
            ) { accum, wallet in
                guard
                    let model = wallet.fetchMetaChainAccount(for: chain.accountRequest()) else {
                    return
                }

                let accountId = model.chainAccount.accountId
                let currentList = accum[accountId]

                accum[accountId] = (currentList ?? []) + [model]
            }

            return localDict.mapValues { accounts in
                let sortedAccounts = accounts.sorted { account1, account2 in
                    let order1 = account1.chainAccount.type.signingDelegateOrder
                    let order2 = account2.chainAccount.type.signingDelegateOrder

                    return order1 < order2
                }

                return sortedAccounts[0]
            }
        }

        mapOperation.addDependency(allWalletsOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [allWalletsOperation]
        )
    }
}
