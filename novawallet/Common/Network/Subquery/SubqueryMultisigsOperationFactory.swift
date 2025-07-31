import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

private typealias FindMultisigsResponse = SubqueryMultisigs.MultisigsResponseQueryWrapper<
    SubqueryMultisigs.FindMultisigsResponse
>
private typealias FetchMultisigCallDataResponse = SubqueryMultisigs.MultisigsResponseQueryWrapper<
    SubqueryMultisigs.FetchMultisigCallDataResponse
>

protocol SubqueryMultisigsOperationFactoryProtocol {
    func createDiscoverMultisigsOperation(
        for accountIds: Set<AccountId>
    ) -> BaseOperation<[DiscoveredMultisig]>

    func createFetchOffChainOperationInfo(
        for accountId: AccountId,
        callHashes: Set<Substrate.CallHash>
    ) -> BaseOperation<[Substrate.CallHash: OffChainMultisigInfo]>
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

    func createCallDataRequestQuery(
        for accountId: AccountId,
        callHashes: Set<Substrate.CallHash>
    ) -> String {
        let callHashesHex = callHashes.map { $0.toHexWithPrefix() }
        let joinedHashHexes = callHashesHex.map { "\"\($0)\"" }.joined(with: .commaSpace)
        let accountIdHex = accountId.toHexWithPrefix()
        let accountIdFilter = "accountId: { equalTo: \"\(accountIdHex)\" }"
        let statusFilter = "status: { equalTo: pending }"
        let callHashFilter = "callHash: { in: [\(joinedHashHexes)] }"

        return """
        {
            query {
                multisigOperations(
                    filter:  {
                        \(accountIdFilter),
                        \(statusFilter),
                        \(callHashFilter)
                    }
                ) {
                    nodes {
                        callHash
                        callData
                        timestamp
                        events(last: 1) {
                            nodes {
                                timestamp
                            }
                        }
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
        ) { (response: FindMultisigsResponse) in
            let nodes: [AccountId: [SubqueryMultisigs.RemoteMultisig]] = response.query.accounts.nodes.reduce(
                into: [:]
            ) { acc, node in
                node.signatories.nodes.forEach {
                    if acc[$0.signatory.id] != nil {
                        acc[$0.signatory.id]?.append(node)
                    } else {
                        acc[$0.signatory.id] = [node]
                    }
                }
            }

            return accountIds.reduce(into: []) { acc, accountId in
                nodes[accountId]?.forEach { remoteMultisig in
                    let discoveredMultisig = DiscoveredMultisig(
                        accountId: remoteMultisig.id,
                        signatory: accountId,
                        signatories: remoteMultisig.signatories.nodes.map(\.signatory.id),
                        threshold: remoteMultisig.threshold
                    )

                    acc.append(discoveredMultisig)
                }
            }
        }

        return operation
    }

    func createFetchOffChainOperationInfo(
        for accountId: AccountId,
        callHashes: Set<Substrate.CallHash>
    ) -> BaseOperation<[Substrate.CallHash: OffChainMultisigInfo]> {
        let query = createCallDataRequestQuery(
            for: accountId,
            callHashes: callHashes
        )

        let operation: BaseOperation<[Substrate.CallHash: OffChainMultisigInfo]>

        operation = createOperation(
            for: query
        ) { (response: FetchMultisigCallDataResponse) in
            response.query.multisigOperations.nodes.reduce(into: [:]) { acc, node in
                guard callHashes.contains(node.callHash) else { return }

                acc[node.callHash] = OffChainMultisigInfo(
                    callHash: node.callHash,
                    callData: node.callData,
                    timestamp: node.events.nodes.first?.timestamp ?? node.timestamp
                )
            }
        }

        return operation
    }
}
