import Foundation
import SubstrateSdk
import Operation_iOS

final class DiscoverMultisigAccountsRepository: SubqueryBaseOperationFactory {
    struct Response: Decodable {
        let accountMultisigs: SubqueryNodes<MultisigWrapper>
    }

    struct MultisigWrapper: Decodable {
        let multisig: Multisig
    }

    struct Multisig: Decodable {
        let threshold: Int
        let signatories: SubqueryNodes<Signatory>
        @HexCodable var accountId: AccountId
    }

    struct Signatory: Decodable {
        @HexCodable var signatoryId: AccountId
    }
}

private extension DiscoverMultisigAccountsRepository {
    func createQuery(for signatoryIds: Set<AccountId>) -> String {
        let filter = SubqueryFilterBuilder.buildBlock(
            SubqueryFieldInnerFilter(
                fieldName: "signatory",
                innerFilter: SubqueryFieldInFilter(
                    fieldName: "id",
                    values: signatoryIds.map { $0.toHexWithPrefix() }
                )
            )
        )

        return """
        {
            accountMultisigs(
                \(filter)
            ) {
                nodes {
                    multisig {
                        threshold
                        signatories {
                            nodes {
                                signatoryId
                            }
                        }
                        accountId
                    }
                }
            }
        }
        """
    }
}

extension DiscoverMultisigAccountsRepository: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegateMapping> {
        let query = createQuery(for: accountIds)

        let queryOperation: BaseOperation<DelegatedAccountsByDelegateMapping> = createOperation(
            for: query
        ) { (response: Response) in
            let multisigs: Set<DiscoveredAccount.MultisigModel> = response.accountMultisigs.nodes.reduce(
                into: []
            ) { accum, multisigWrapper in
                let signatories = multisigWrapper.multisig.signatories.nodes.map(\.signatoryId)

                for signatory in signatories where accountIds.contains(signatory) {
                    accum.insert(
                        DiscoveredAccount.MultisigModel(
                            accountId: multisigWrapper.multisig.accountId,
                            signatory: signatory,
                            signatories: signatories,
                            threshold: multisigWrapper.multisig.threshold
                        )
                    )
                }
            }

            return multisigs.reduce(into: DelegatedAccountsByDelegateMapping()) { accum, multisig in
                let prev = accum[multisig.signatory] ?? []
                accum[multisig.signatory] = prev + [multisig]
            }
        }

        return CompoundOperationWrapper(targetOperation: queryOperation)
    }
}
