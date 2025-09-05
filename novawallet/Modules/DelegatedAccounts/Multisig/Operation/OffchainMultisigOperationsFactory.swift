import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol OffchainMultisigOperationsFactoryProtocol {
    func createFetchOffChainOperationInfo(
        for accountId: AccountId,
        callHashes: Set<Substrate.CallHash>
    ) -> CompoundOperationWrapper<[Substrate.CallHash: OffChainMultisigInfo]>
}

final class OffchainMultisigOperationsFactory: SubqueryBaseOperationFactory {
    struct Response: Decodable {
        let multisigOperations: SubqueryNodes<MultisigOperation>
    }

    struct MultisigOperation: Decodable {
        @HexCodable var callHash: Substrate.CallHash
        @OptionHexCodable var callData: Substrate.CallData?
        let timestamp: Int
        let events: SubqueryNodes<OperationEvent>
    }

    struct OperationEvent: Decodable {
        let timestamp: Int
    }

    let chainId: ChainModel.Id

    init(url: URL, chainId: ChainModel.Id) {
        self.chainId = chainId

        super.init(url: url)
    }
}

// MARK: Private

private extension OffchainMultisigOperationsFactory {
    func createCallDataRequestQuery(
        for accountId: AccountId,
        callHashes: Set<Substrate.CallHash>
    ) -> String {
        let filter = SubqueryFilterBuilder.buildBlock(
            SubqueryCompoundFilter.and(
                [
                    SubqueryEqualToFilter(
                        fieldName: "accountId",
                        value: accountId.toHexWithPrefix()
                    ),
                    SubqueryEqualToFilter(
                        fieldName: "chainId",
                        value: chainId.withHexPrefix()
                    ),
                    SubqueryEqualToFilter(
                        fieldName: "status",
                        value: SubqueryStringConvertibleValue(value: "pending")
                    ),
                    SubqueryFieldInFilter(
                        fieldName: "callHash",
                        values: callHashes.map { $0.toHexWithPrefix() }
                    )
                ]
            )
        )

        return """
        {
            multisigOperations(
                \(filter)
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
        """
    }
}

// MARK: SubqueryMultisigsOperationFactoryProtocol

extension OffchainMultisigOperationsFactory: OffchainMultisigOperationsFactoryProtocol {
    func createFetchOffChainOperationInfo(
        for accountId: AccountId,
        callHashes: Set<Substrate.CallHash>
    ) -> CompoundOperationWrapper<[Substrate.CallHash: OffChainMultisigInfo]> {
        guard !callHashes.isEmpty else {
            return .createWithResult([:])
        }

        let query = createCallDataRequestQuery(
            for: accountId,
            callHashes: callHashes
        )

        let operation: BaseOperation<[Substrate.CallHash: OffChainMultisigInfo]>

        operation = createOperation(
            for: query
        ) { (response: Response) in
            response.multisigOperations.nodes.reduce(into: [:]) { acc, node in
                guard callHashes.contains(node.callHash) else { return }

                acc[node.callHash] = OffChainMultisigInfo(
                    callHash: node.callHash,
                    callData: node.callData,
                    timestamp: node.events.nodes.first?.timestamp ?? node.timestamp
                )
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
