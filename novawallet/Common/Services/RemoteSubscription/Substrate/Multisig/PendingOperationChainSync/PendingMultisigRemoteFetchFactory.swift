import Foundation
import Operation_iOS
import SubstrateSdk

protocol PendingMultisigRemoteFetchFactoryProtocol {
    func createFetchWrapper() -> CompoundOperationWrapper<MultisigPendingOperationsMap>
}

final class PendingMultisigRemoteFetchFactory {
    private let multisigAccount: DelegatedAccount.MultisigAccountModel
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        multisigAccount: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.multisigAccount = multisigAccount
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.operationManager = operationManager
    }
}

// MARK: - Private

private extension PendingMultisigRemoteFetchFactory {
    func createCallHashFetchWrapper() -> CompoundOperationWrapper<CallHashFetchResult> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            return pendingCallHashesOperationFactory.fetchPendingOperations(
                for: multisigAccount.accountId,
                connection: connection,
                runtimeProvider: runtimeProvider
            )
        } catch {
            return .createWithError(error)
        }
    }

    func createCallDataFetchWrapper(
        dependsOn callHashesWrapper: CompoundOperationWrapper<CallHashFetchResult>
    ) -> CompoundOperationWrapper<CallDataFetchResult> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let callHashes = try callHashesWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .keys

            guard let apiURL = chain.externalApis?.getApis(for: .multisig)?.first?.url else {
                return .createWithResult([:])
            }

            let remoteCallDataFetchFactory = SubqueryMultisigsOperationFactory(url: apiURL)

            let callDataFetchOperation = remoteCallDataFetchFactory.createFetchCallDataOperation(
                for: Set(callHashes)
            )

            return CompoundOperationWrapper(targetOperation: callDataFetchOperation)
        }
    }

    func createCallsDecodingWrapper(
        dependsOn callDataWrapper: CompoundOperationWrapper<CallDataFetchResult>,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<CallsFetchResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<CallsFetchResult> { [weak self] in
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let callData = try callDataWrapper.targetOperation.extractNoCancellableResultData()

            return try callData.compactMapValues {
                try self?.extractDecodedCall(from: $0, using: codingFactory)
            }
        }

        mapOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    func extractDecodedCall(
        from extrinsicData: Data,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> JSON {
        let decoder = try codingFactory.createDecoder(from: extrinsicData)
        let context = codingFactory.createRuntimeJsonContext()

        return try decoder.read(
            of: GenericType.call.name,
            with: context.toRawContext()
        )
    }

    func createPendingOperations(
        with callHashes: CallHashFetchResult,
        calls: CallsFetchResult
    ) -> MultisigPendingOperationsMap {
        callHashes.reduce(into: [:]) { acc, keyValue in
            let callHash = keyValue.key
            let operationDefinition = keyValue.value

            let operation = Multisig.PendingOperation(
                call: calls[callHash],
                callHash: callHash,
                multisigAccountId: multisigAccount.accountId,
                signatory: multisigAccount.signatory,
                chainId: chain.chainId,
                multisigDefinition: .init(from: operationDefinition)
            )

            acc[operation.createKey()] = operation
        }
    }
}

// MARK: - PendingMultisigRemoteFetchFactoryProtocol

extension PendingMultisigRemoteFetchFactory: PendingMultisigRemoteFetchFactoryProtocol {
    func createFetchWrapper() -> CompoundOperationWrapper<MultisigPendingOperationsMap> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            let callHashFetchWrapper = createCallHashFetchWrapper()
            let callDataFetchWrapper = createCallDataFetchWrapper(dependsOn: callHashFetchWrapper)
            let callsDecodingWrapper = createCallsDecodingWrapper(
                dependsOn: callDataFetchWrapper,
                runtimeProvider: runtimeProvider
            )

            let mapOperation: BaseOperation<MultisigPendingOperationsMap>
            mapOperation = ClosureOperation { [weak self] in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                return createPendingOperations(
                    with: try callHashFetchWrapper.targetOperation.extractNoCancellableResultData(),
                    calls: try callsDecodingWrapper.targetOperation.extractNoCancellableResultData()
                )
            }

            callDataFetchWrapper.addDependency(wrapper: callHashFetchWrapper)
            callsDecodingWrapper.addDependency(wrapper: callDataFetchWrapper)
            mapOperation.addDependency(callsDecodingWrapper.targetOperation)

            return callsDecodingWrapper
                .insertingHead(operations: callDataFetchWrapper.allOperations)
                .insertingHead(operations: callHashFetchWrapper.allOperations)
                .insertingTail(operation: mapOperation)
        } catch {
            return .createWithError(error)
        }
    }
}

// MARK: - Private types

private typealias CallHashFetchResult = [Substrate.CallHash: MultisigPallet.MultisigDefinition]
private typealias CallDataFetchResult = [Substrate.CallHash: Substrate.CallData]
private typealias CallsFetchResult = [Substrate.CallHash: JSON]
