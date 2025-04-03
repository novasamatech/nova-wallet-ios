import Foundation
import SubstrateSdk
import Operation_iOS
import NovaCrypto

struct IdentityChainParams {
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
}

protocol IdentityOperationFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        identityChainParams: IdentityChainParams,
        originChainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]>
}

extension IdentityOperationFactoryProtocol {
    func createIdentityWrapperByAccountId(
        for accountIdClosure: @escaping () throws -> [AccountId],
        identityChainParams: IdentityChainParams,
        originChainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]> {
        let wrapper = createIdentityWrapper(
            for: accountIdClosure,
            identityChainParams: identityChainParams,
            originChainFormat: originChainFormat
        )

        let mapOperation = ClosureOperation<[AccountId: AccountIdentity]> {
            let identities = try wrapper.targetOperation.extractNoCancellableResultData()

            return identities.reduce(into: [AccountId: AccountIdentity]()) { result, keyValue in
                guard let accountId = try? keyValue.key.toAccountId() else {
                    return
                }

                return result[accountId] = keyValue.value
            }
        }

        mapOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }
}

final class IdentityOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol
    let emptyIdentitiesWhenNoStorage: Bool

    init(requestFactory: StorageRequestFactoryProtocol, emptyIdentitiesWhenNoStorage: Bool = true) {
        self.requestFactory = requestFactory
        self.emptyIdentitiesWhenNoStorage = emptyIdentitiesWhenNoStorage
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
        runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        chainFormat: ChainFormat,
        emptyWhenNoStorage _: Bool
    ) -> BaseOperation<[AccountAddress: AccountIdentity]> {
        ClosureOperation<[AccountAddress: AccountIdentity]> {
            do {
                let superIdentities = try superOperation.extractNoCancellableResultData()
                let coderFactory = try runtimeOperation.extractNoCancellableResultData()
                let identities = try identityOperation.extractNoCancellableResultData()
                    .reduce(into: [AccountAddress: Identity]()) { result, item in
                        if let value = item.value {
                            let address = try LastAccountIdKey.decodeStorageKey(
                                from: item.key,
                                path: .identity,
                                coderFactory: coderFactory
                            ).value.toAddress(using: chainFormat)

                            result[address] = value
                        }
                    }

                return try superIdentities.reduce(into: [String: AccountIdentity]()) { result, item in
                    let address = try LastAccountIdKey.decodeStorageKey(
                        from: item.key,
                        path: .superIdentity,
                        coderFactory: coderFactory
                    ).value.toAddress(using: chainFormat)

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
            } catch StorageKeyEncodingOperationError.invalidStoragePath {
                return [:]
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
            let coderFactory = try runtimeOperation.extractNoCancellableResultData()
            return try responses.map { response in
                if let value = response.value {
                    return value.parentAccountId
                } else {
                    return try LastAccountIdKey.decodeStorageKey(
                        from: response.key,
                        path: .superIdentity,
                        coderFactory: coderFactory
                    ).value
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
            runtimeOperation: runtimeOperation,
            chainFormat: chainFormat,
            emptyWhenNoStorage: emptyIdentitiesWhenNoStorage
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
        identityChainParams: IdentityChainParams,
        originChainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let coderFactoryOperation = identityChainParams.runtimeService.fetchCoderFactoryOperation()

        let superIdentityWrapper = createSuperIdentityOperation(
            dependingOn: coderFactoryOperation,
            accountIds: accountIdClosure,
            engine: identityChainParams.connection
        )

        superIdentityWrapper.allOperations.forEach {
            $0.addDependency(coderFactoryOperation)
        }

        let identityWrapper = createIdentityWrapper(
            dependingOn: superIdentityWrapper.targetOperation,
            runtimeOperation: coderFactoryOperation,
            engine: identityChainParams.connection,
            chainFormat: originChainFormat
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
