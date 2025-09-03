import Foundation
import Operation_iOS

protocol MultisigSignatoryRepositoryProtocol {
    func fetchSignatories(
        for multisig: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[Multisig.Signatory]>
}

final class MultisigSignatoryRepository {
    let repository: AnyDataProviderRepository<MetaAccountModel>

    init(repository: AnyDataProviderRepository<MetaAccountModel>) {
        self.repository = repository
    }
}

private extension MultisigSignatoryRepository {
    func createLocalSearchWrapper(
        dependingOn walletsOperation: BaseOperation<[MetaAccountModel]>,
        chain: ChainModel,
        signatories: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: Multisig.Signatory]> {
        let searchOperation = ClosureOperation<[AccountId: Multisig.Signatory]> {
            let wallets = try walletsOperation.extractNoCancellableResultData()

            let localDict = wallets.reduce(
                into: [AccountId: [MetaChainAccountResponse]]()
            ) { accum, wallet in
                guard let model = wallet.fetchMetaChainAccount(for: chain.accountRequest()) else {
                    return
                }

                let accountId = model.chainAccount.accountId
                let currentList = accum[accountId]

                accum[accountId] = (currentList ?? []) + [model]
            }

            return localDict.reduce(
                into: [AccountId: MetaChainAccountResponse]()
            ) { accum, keyValue in
                let accountId = keyValue.key
                let accounts = keyValue.value

                guard signatories.contains(accountId) else { return }

                let sortedAccounts = accounts.sorted(by: self.accountsSortBlock)

                accum[accountId] = sortedAccounts[0]
            }.mapValues { account in
                var delegate: Multisig.LocalSignatory.Delegate?

                if
                    let delegationId = account.delegationId,
                    let delegateAccount = localDict[delegationId.delegateAccountId]?
                    .sorted(by: self.accountsSortBlock)
                    .first {
                    delegate = Multisig.LocalSignatory.Delegate(
                        metaAccount: delegateAccount,
                        delegationType: delegationId.delegateType
                    )
                }

                return Multisig.Signatory.local(.init(metaAccount: account, delegate: delegate))
            }
        }

        return CompoundOperationWrapper(targetOperation: searchOperation)
    }

    func accountsSortBlock(
        lhs: MetaChainAccountResponse,
        rhs: MetaChainAccountResponse
    ) -> Bool {
        let order1 = lhs.chainAccount.type.signingDelegateOrder
        let order2 = rhs.chainAccount.type.signingDelegateOrder

        return order1 < order2
    }
}

extension MultisigSignatoryRepository: MultisigSignatoryRepositoryProtocol {
    func fetchSignatories(
        for multisig: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[Multisig.Signatory]> {
        let allWalletsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let signatories = Set([multisig.signatory] + multisig.otherSignatories)

        let localSignatoryWrapper = createLocalSearchWrapper(
            dependingOn: allWalletsOperation,
            chain: chain,
            signatories: signatories
        )

        localSignatoryWrapper.addDependency(operations: [allWalletsOperation])

        let mergeOperation = ClosureOperation<[Multisig.Signatory]> {
            let localSignatories = try localSignatoryWrapper.targetOperation.extractNoCancellableResultData()

            return signatories.map { accountId in
                if let localSignatory = localSignatories[accountId] {
                    localSignatory
                } else {
                    .remote(Multisig.RemoteSignatory(accountId: accountId))
                }
            }
        }

        mergeOperation.addDependency(localSignatoryWrapper.targetOperation)

        return localSignatoryWrapper
            .insertingHead(operations: [allWalletsOperation])
            .insertingTail(operation: mergeOperation)
    }
}
