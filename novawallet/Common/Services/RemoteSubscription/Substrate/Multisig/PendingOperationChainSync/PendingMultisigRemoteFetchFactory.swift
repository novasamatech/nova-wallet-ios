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

    func createOperationInfoFetchWrapper(
        dependsOn callHashesWrapper: CompoundOperationWrapper<CallHashFetchResult>
    ) -> CompoundOperationWrapper<OffChainInfoFetchResult> {
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

            let operationInfoFetchOperation = remoteCallDataFetchFactory.createFetchOffChainOperationInfo(
                for: multisigAccount.accountId,
                callHashes: Set(callHashes)
            )

            return CompoundOperationWrapper(targetOperation: operationInfoFetchOperation)
        }
    }

    func createCallsDecodingWrapper(
        dependsOn callDataWrapper: CompoundOperationWrapper<OffChainInfoFetchResult>,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<OffChainInfoDecodingResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<OffChainInfoDecodingResult> { [weak self] in
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let offChainOperationInfo = try callDataWrapper.targetOperation.extractNoCancellableResultData()

            return try offChainOperationInfo.compactMapValues {
                let call: JSON? = if let callData = $0.callData {
                    try self?.extractDecodedCall(from: callData, using: codingFactory)
                } else {
                    nil
                }

                return Multisig.OffChainMultisigInfo(
                    callHash: $0.callHash,
                    call: call,
                    timestamp: $0.timestamp
                )
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
        info: OffChainInfoDecodingResult
    ) -> MultisigPendingOperationsMap {
        callHashes.reduce(into: [:]) { acc, keyValue in
            let callHash = keyValue.key
            let operationDefinition = keyValue.value

            let operation = Multisig.PendingOperation(
                call: info[callHash]?.call,
                callHash: callHash,
                timestamp: 0,
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
            let callDataFetchWrapper = createOperationInfoFetchWrapper(dependsOn: callHashFetchWrapper)
            let callsDecodingWrapper = createCallsDecodingWrapper(
                dependsOn: callDataFetchWrapper,
                runtimeProvider: runtimeProvider
            )

            let mapOperation: BaseOperation<MultisigPendingOperationsMap>
            mapOperation = ClosureOperation { [weak self] in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                return createPendingOperations(
                    with: try callHashFetchWrapper.targetOperation.extractNoCancellableResultData(),
                    info: try callsDecodingWrapper.targetOperation.extractNoCancellableResultData()
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
private typealias OffChainInfoFetchResult = [Substrate.CallHash: OffChainMultisigInfo]
private typealias OffChainInfoDecodingResult = [Substrate.CallHash: Multisig.OffChainMultisigInfo]
