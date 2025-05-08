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
        _ response: SubqueryMultisigs.FindMultisigsResponse
    ) throws -> [DiscoveredMultisig] {
        try response.accounts.nodes.map { node in
            DiscoveredMultisig(
                accountId: try Data(hexString: node.id),
                signatories: try node.signatories.nodes.map { try Data(hexString: $0.signatory.id) },
                threshold: node.threshold
            )
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

        operation = createOperation(for: query) { [weak self] (response: SubqueryMultisigs.FindMultisigsResponseQueryWrapper) in
            try self?.mapResponse(response.query)
        }

        return operation
    }
}
