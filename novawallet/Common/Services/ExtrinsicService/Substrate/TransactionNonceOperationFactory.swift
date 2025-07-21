import Foundation
import SubstrateSdk
import Operation_iOS

protocol TransactionNonceOperationFactoryProtocol {
    func createWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        accountIdClosure: @escaping () throws -> AccountId
    ) -> CompoundOperationWrapper<UInt32>
}

final class TransactionNonceOperationFactory {}

extension TransactionNonceOperationFactory: TransactionNonceOperationFactoryProtocol {
    func createWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        accountIdClosure: @escaping () throws -> AccountId
    ) -> CompoundOperationWrapper<UInt32> {
        let operation = JSONRPCListOperation<UInt32>(
            engine: connection,
            method: RPCMethod.getExtrinsicNonce
        )

        operation.configurationBlock = {
            do {
                let accountId = try accountIdClosure()
                let address = try accountId.toAddress(using: chain.chainFormat)
                operation.parameters = [address]
            } catch {
                operation.result = .failure(error)
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
