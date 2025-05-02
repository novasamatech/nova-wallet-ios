import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol SubqueryMultisigsOperationFactoryProtocol {
    func createDiscoverMultisigsOperation(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<[DiscoveredMultisig]?>
}

final class SubqueryMultisigsOperationFactory: SubqueryBaseOperationFactory {}

// MARK: Private

private extension SubqueryMultisigsOperationFactory {
    func createRequestQuery(for accountIds: [AccountId]) -> String {
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
        response.accounts.nodes.map { node in
            DiscoveredMultisig(
                signatory: node.id,
                signatories: node.signatories.nodes.map { $0.signatory.id },
                threshold: node.threshold)
        }
    }
}

// MARK: SubqueryMultisigsOperationFactoryProtocol

extension SubqueryMultisigsOperationFactory {
    func createDiscoverMultisigsOperation(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<[DiscoveredMultisig]?> {
        let query = createRequestQuery(for: accountIds)
        
        let operation: BaseOperation<[DiscoveredMultisig]?>
        
        operation = createOperation(for: query) { [weak self] (response: SubqueryMultisigs.FindMultisigsResponse) in
            try self?.mapResponse(response)
        }
        
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
