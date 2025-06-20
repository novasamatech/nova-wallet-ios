import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol SubqueryMultisigsOperationFactoryProtocol {
    func createDiscoverMultisigsOperation(
        for accountIds: Set<AccountId>
    ) -> BaseOperation<[DiscoveredMultisig]?>
}

final class SubqueryMultisigsOperationFactory: SubqueryBaseOperationFactory {}

// MARK: Private

private extension SubqueryMultisigsOperationFactory {
    func createRequestQuery(for accountIds: Set<AccountId>) -> String {
        let accountIdsHex = accountIds.map { $0.toHexWithPrefix() }
        let idsInFilter = accountIdsHex.map { "\"\($0)\"" }.joined(with: .commaSpace)

        return """
        {
            query {
                accounts(
                    filter: {
                        signatories: {
                            some: {
                                signatory: {
                                    id: { in: [\(idsInFilter)] }
                                }
                            }
                        }
                        isMultisig: { equalTo: true }
                    }
                ) {
                    nodes {
                        id
                        threshold
                        signatories {
                            nodes {
                                signatory {
                                    id
                                }
                            }
                        }
                    }
                }
            }
        }
        """
    }

    func mapResponse(
        _ response: SubqueryMultisigs.FindMultisigsResponse,
        _ accountIds: Set<AccountId>
    ) -> [DiscoveredMultisig] {
        accountIds.flatMap { accountId in
            response.accounts.nodes
                .filter { $0.signatories.nodes.contains { $0.signatory.id == accountId } }
                .map {
                    DiscoveredMultisig(
                        accountId: $0.id,
                        signatory: accountId,
                        signatories: $0.signatories.nodes.map(\.signatory.id),
                        threshold: $0.threshold
                    )
                }
        }
    }
}

// MARK: SubqueryMultisigsOperationFactoryProtocol

extension SubqueryMultisigsOperationFactory: SubqueryMultisigsOperationFactoryProtocol {
    func createDiscoverMultisigsOperation(
        for accountIds: Set<AccountId>
    ) -> BaseOperation<[DiscoveredMultisig]?> {
        let query = createRequestQuery(for: accountIds)

        let operation: BaseOperation<[DiscoveredMultisig]?>

        operation = createOperation(
            for: query
        ) { [weak self] (response: SubqueryMultisigs.FindMultisigsResponseQueryWrapper) in
            self?.mapResponse(response.query, accountIds)
        }

        return operation
    }
}
