import Foundation
import RobinHood
import SubstrateSdk

protocol UniquesOperationFactoryProtocol {
    func createAccountKeysWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UniquesAccountKey]>
}

final class UniquesOperationFactory: UniquesOperationFactoryProtocol {
    func createAccountKeysWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UniquesAccountKey]> {
        let keyEncodingOperation = MapKeyEncodingOperation(
            path: .uniquesAccount,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [accountId]
        )

        keyEncodingOperation.configurationBlock = {
            do {
                keyEncodingOperation.codingFactory = try codingFactoryClosure()
            } catch {
                keyEncodingOperation.result = .failure(error)
            }
        }

        let keysFetchOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: operationManager,
            prefixKeyClosure: {
                guard
                    let prefix = try keyEncodingOperation.extractNoCancellableResultData().first else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                return prefix
            },
            mapper: AnyMapper(mapper: IdentityMapper())
        ).longrunOperation()

        keysFetchOperation.addDependency(keyEncodingOperation)

        let decodingOperation = StorageKeyDecodingOperation<UniquesAccountKey>(path: .uniquesAccount)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryClosure()
                decodingOperation.dataList = try keysFetchOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(keysFetchOperation)

        let dependencies = [keyEncodingOperation, keysFetchOperation]

        return CompoundOperationWrapper(targetOperation: decodingOperation, dependencies: dependencies)
    }
}
