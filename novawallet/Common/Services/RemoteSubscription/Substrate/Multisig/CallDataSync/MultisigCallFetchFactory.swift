import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigCallFetchFactoryProtocol {
    func createCallFetchWrapper(
        for events: [MultisigEvent],
        at blockHash: Data,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<[Multisig.PendingOperation.Key: MultisigCallOrHash]>
}

final class MultisigCallFetchFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let blockQueryFactory: BlockEventsQueryFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        blockQueryFactory: BlockEventsQueryFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.blockQueryFactory = blockQueryFactory
    }
}

// MARK: - Private

private extension MultisigCallFetchFactory {
    func extractMultisigCallDataOrHash(
        from blockDetails: SubstrateBlockDetails,
        matching multisigEvents: Set<MultisigEvent>,
        chainId: ChainModel.Id,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [Multisig.PendingOperation.Key: MultisigCallOrHash] {
        try blockDetails.extrinsicsWithEvents.reduce(into: [:]) { acc, indexedExtrinsicWithEvents in
            try indexedExtrinsicWithEvents.eventRecords.forEach { eventRecord in
                let matcher = MultisigEventMatcher(codingFactory: codingFactory)

                guard
                    let blockMultisigEvent = matcher.matchMultisig(event: eventRecord.event),
                    multisigEvents.contains(blockMultisigEvent)
                else { return }

                let key = Multisig.PendingOperation.Key(
                    callHash: blockMultisigEvent.callHash,
                    chainId: chainId,
                    multisigAccountId: blockMultisigEvent.accountId
                )

                let callOrHash: MultisigCallOrHash = if let call = try matchAsMultiCallData(
                    for: blockMultisigEvent.callHash,
                    from: indexedExtrinsicWithEvents.extrinsicData,
                    using: codingFactory
                ) {
                    .call(call)
                } else {
                    .callHash(blockMultisigEvent.callHash)
                }

                acc[key] = callOrHash
            }
        }
    }

    func matchAsMultiCallData(
        for callHash: CallHash,
        from extrinsicData: Data,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> JSON? {
        let decoder = try codingFactory.createDecoder(from: extrinsicData)
        let extrinsic: Extrinsic = try decoder.read(of: GenericType.extrinsic.name)

        let context = codingFactory.createRuntimeJsonContext()

        guard let sender = ExtrinsicExtraction.getSender(
            from: extrinsic,
            codingFactory: codingFactory
        ) else { return nil }

        return try findCall(
            with: callHash,
            in: extrinsic.call,
            sender: sender,
            context: context
        )
    }

    func findCall(
        with callHash: CallHash,
        in call: JSON,
        sender: AccountId,
        context: RuntimeJsonContext
    ) throws -> JSON? {
        let nestedCallMapper = NestedExtrinsicCallMapper(extrinsicSender: sender)

        let maybeCallMappingResult: NestedExtrinsicCallMapResult<RuntimeCall<MultisigPallet.AsMultiCall>>
        maybeCallMappingResult = try nestedCallMapper.mapRuntimeCall(
            call: call,
            context: context
        )

        let foundCalls = maybeCallMappingResult.node.calls.map(\.args.call)

        return try foundCalls.first { foundCall in
            let foundCallData = try JSONEncoder.scaleCompatible(with: context.toRawContext()).encode(foundCall)
            let foundCallHash = try StorageHasher.blake256.hash(data: foundCallData)

            return callHash == foundCallHash
        }
    }
}

// MARK: - MultisigCallFetchFactoryProtocol

extension MultisigCallFetchFactory: MultisigCallFetchFactoryProtocol {
    func createCallFetchWrapper(
        for events: [MultisigEvent],
        at blockHash: Data,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<[Multisig.PendingOperation.Key: MultisigCallOrHash]> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let blockQueryWrapper = blockQueryFactory.queryBlockDetailsWrapper(
                from: connection,
                runtimeProvider: runtimeProvider,
                blockHash: blockHash
            )

            let callExtractionOperation = ClosureOperation<[Multisig.PendingOperation.Key: MultisigCallOrHash]> {
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                let blockDetails = try blockQueryWrapper.targetOperation.extractNoCancellableResultData()

                return try self.extractMultisigCallDataOrHash(
                    from: blockDetails,
                    matching: Set(events),
                    chainId: chainId,
                    using: codingFactory
                )
            }

            callExtractionOperation.addDependency(codingFactoryOperation)
            callExtractionOperation.addDependency(blockQueryWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: callExtractionOperation,
                dependencies: [codingFactoryOperation] + blockQueryWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }
}
