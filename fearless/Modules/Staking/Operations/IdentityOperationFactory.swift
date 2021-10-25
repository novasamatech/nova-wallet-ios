import Foundation
import FearlessUtils
import RobinHood
import IrohaCrypto

protocol IdentityOperationFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]>
}

final class IdentityOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createSuperIdentityOperation(
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIds: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine
    ) -> SuperIdentityWrapper {
        let path = StorageCodingPath.superIdentity

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try coderFactoryOperation.extractNoCancellableResultData()
        }

        let superIdentityWrapper: SuperIdentityWrapper = requestFactory.queryItems(
            engine: engine,
            keyParams: accountIds,
            factory: factory,
            storagePath: path
        )

        return superIdentityWrapper
    }

    private func createIdentityMergeOperation(
        dependingOn superOperation: SuperIdentityOperation,
        identityOperation: IdentityOperation,
        chainFormat: ChainFormat
    ) -> BaseOperation<[AccountAddress: AccountIdentity]> {
        ClosureOperation<[AccountAddress: AccountIdentity]> {
            let superIdentities = try superOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()
                .reduce(into: [AccountAddress: Identity]()) { result, item in
                    if let value = item.value {
                        let address = try item.key.getAccountIdFromKey().toAddress(using: chainFormat)
                        result[address] = value
                    }
                }

            return try superIdentities.reduce(into: [String: AccountIdentity]()) { result, item in
                let address = try item.key.getAccountIdFromKey().toAddress(using: chainFormat)

                if let value = item.value {
                    let parentAddress = try value.parentAccountId.toAddress(using: chainFormat)

                    if let parentIdentity = identities[parentAddress] {
                        result[address] = AccountIdentity(
                            name: value.data.stringValue ?? "",
                            parentAddress: parentAddress,
                            parentName: parentIdentity.info.display.stringValue,
                            identity: parentIdentity.info
                        )
                    } else {
                        result[address] = AccountIdentity(name: value.data.stringValue ?? "")
                    }

                } else if let identity = identities[address] {
                    result[address] = AccountIdentity(
                        name: identity.info.display.stringValue ?? "",
                        parentAddress: nil,
                        parentName: nil,
                        identity: identity.info
                    )
                }
            }
        }
    }

    private func createIdentityWrapper(
        dependingOn superIdentityOperation: SuperIdentityOperation,
        runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        engine: JSONRPCEngine,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let path = StorageCodingPath.identity

        let keyParams: () throws -> [Data] = {
            let responses = try superIdentityOperation.extractNoCancellableResultData()
            return responses.map { response in
                if let value = response.value {
                    return value.parentAccountId
                } else {
                    return response.key.getAccountIdFromKey()
                }
            }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtimeOperation.extractNoCancellableResultData()
        }

        let identityWrapper: IdentityWrapper = requestFactory.queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: factory,
            storagePath: path
        )

        let mergeOperation = createIdentityMergeOperation(
            dependingOn: superIdentityOperation,
            identityOperation: identityWrapper.targetOperation,
            chainFormat: chainFormat
        )

        mergeOperation.addDependency(identityWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: identityWrapper.allOperations
        )
    }
}

extension IdentityOperationFactory: IdentityOperationFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let superIdentityWrapper = createSuperIdentityOperation(
            dependingOn: coderFactoryOperation,
            accountIds: accountIdClosure,
            engine: engine
        )

        superIdentityWrapper.allOperations.forEach {
            $0.addDependency(coderFactoryOperation)
        }

        let identityWrapper = createIdentityWrapper(
            dependingOn: superIdentityWrapper.targetOperation,
            runtimeOperation: coderFactoryOperation,
            engine: engine,
            chainFormat: chainFormat
        )

        identityWrapper.allOperations.forEach {
            $0.addDependency(superIdentityWrapper.targetOperation)
            $0.addDependency(coderFactoryOperation)
        }

        let dependencies = identityWrapper.dependencies + superIdentityWrapper.allOperations
            + [coderFactoryOperation]

        return CompoundOperationWrapper(
            targetOperation: identityWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}
