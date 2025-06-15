import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

typealias CallData = Data

protocol SubqueryMultisigsOperationFactoryProtocol {
    func createDiscoverMultisigsOperation(
        for accountIds: Set<AccountId>
    ) -> BaseOperation<[DiscoveredMultisig]>

    func createFetchCallDataOperation(
        for callHashes: Set<CallHash>
    ) -> BaseOperation<[CallHash: CallData]>
}

final class SubqueryMultisigsOperationFactory: SubqueryBaseOperationFactory {}

// MARK: Private

private extension SubqueryMultisigsOperationFactory {
    func createDiscoverMultisigsRequestQuery(for accountIds: Set<AccountId>) -> String {
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

    func createCallDataRequestQuery(for callHashes: Set<CallHash>) -> String {
        let callHashesHex = callHashes.map { $0.toHexWithPrefix() }
        let hashInFilter = callHashesHex.map { "\"\($0)\"" }.joined(with: .commaSpace)

        return """
        {
            query {
                multisigOperations(
                    filter:  {
                        callHash: { in: [\(hashInFilter)] }
                    }
                ) {
                    nodes {
                        callHash
                        callData
                    }
                }
            }
        }
        """
    }
}

// MARK: SubqueryMultisigsOperationFactoryProtocol

extension SubqueryMultisigsOperationFactory: SubqueryMultisigsOperationFactoryProtocol {
    func createDiscoverMultisigsOperation(
        for accountIds: Set<AccountId>
    ) -> BaseOperation<[DiscoveredMultisig]> {
        let query = createDiscoverMultisigsRequestQuery(for: accountIds)

        let operation: BaseOperation<[DiscoveredMultisig]>

        operation = createOperation(
            for: query
        ) { (response: SubqueryMultisigs.MultisigsResponseQueryWrapper<SubqueryMultisigs.FindMultisigsResponse>) in
            accountIds.flatMap { accountId in
                response.query.accounts.nodes
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

        return operation
    }

    func createFetchCallDataOperation(
        for callHashes: Set<CallHash>
    ) -> BaseOperation<[CallHash: CallData]> {
        let query = createCallDataRequestQuery(for: callHashes)

        let operation: BaseOperation<[CallHash: CallData]>

        operation = createOperation(
            for: query
        ) { (response: SubqueryMultisigs.MultisigsResponseQueryWrapper<SubqueryMultisigs.FetchMultisigCallDataResponse>) in
            callHashes.reduce(into: [:]) { acc, callHash in
                acc[callHash] = response.query.multisigOperations.nodes
                    .first { $0.callHash == callHash }?
                    .callData
            }
        }

        return operation
    }
}
