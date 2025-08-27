import Foundation
import SubstrateSdk
import Operation_iOS

final class DiscoverMultisigAccountsRepository: SubqueryBaseOperationFactory {
    struct Response: Decodable {
        let accounts: SubqueryNodes<MultisigWrapper>
    }
    
    struct MultisigWrapper: Decodable {
        let multisig: Multisig
    }
    
    struct Multisig: Decodable {
        let threshold: Int
    }

    struct RemoteSignatoryWrapper: Decodable {
        let signatory: RemoteSignatory
    }

    struct Signatory: Decodable {
        @HexCodable var id: AccountId
    }
}

private extension DiscoverMultisigAccountsRepository {
    func createQuery(for signatoryIds: Set<AccountId>) -> String {
        let filter = SubqueryFilterBuilder.buildBlock(
            SubqueryFieldInnerFilter(
                fieldName: "signatory",
                innerFilter: SubqueryFieldInFilter(
                    fieldName: "id",
                    values: signatoryIds.map({ $0.toHexWithPrefix() })
                )
            )
        )
        
        return """
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
        """
    }
}

extension DiscoverMultisigAccountsRepository: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for signatoryIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
        
    }
}
