import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigCallFetchFactoryProtocol {
    func createCallFetchWrapper(
        for events: [MultisigEvent],
        at blockHash: Data,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<[Multisig.PendingOperation.Key: MultisigCallFromEvent]>
}

final class MultisigCallFetchFactory {
    private let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

// MARK: - Private

private extension MultisigCallFetchFactory {
    func extractMultisigCalls(
        from block: Block,
        matching multisigEvents: Set<MultisigEvent>,
        chainId: ChainModel.Id,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [Multisig.PendingOperation.Key: MultisigCallFromEvent] {
        guard let blockNumber = BlockNumber(block.header.number) else {
            return [:]
        }

        return try multisigEvents.reduce(into: [:]) { acc, multisigEvent in
            let extrinsicIndex = Int(multisigEvent.extrinsicIndex)

            guard block.extrinsics.count > extrinsicIndex else { return }

            let extrinsicHex = block.extrinsics[extrinsicIndex]
            let extrinsicData = try Data(hexString: extrinsicHex)

            let key = Multisig.PendingOperation.Key(
                callHash: multisigEvent.callHash,
                chainId: chainId,
                multisigAccountId: multisigEvent.accountId,
                signatoryAccountId: multisigEvent.signatory
            )

            let callOrHash: MultisigCallOrHash = if let call = try matchAsMultiCallData(
                for: multisigEvent.callHash,
                from: extrinsicData,
                using: codingFactory
            ) {
                .call(call)
            } else {
                .callHash(multisigEvent.callHash)
            }

            let timepoint = matchTimepoint(
                for: multisigEvent,
                blockNumber: blockNumber,
                extrinsicIndex: ExtrinsicIndex(extrinsicIndex)
            )

            acc[key] = MultisigCallFromEvent(
                callOrHash: callOrHash,
                timepoint: timepoint,
                blockNumber: blockNumber,
                extrinsicIndex: ExtrinsicIndex(extrinsicIndex)
            )
        }
    }

    func matchTimepoint(
        for event: MultisigEvent,
        blockNumber: BlockNumber,
        extrinsicIndex: ExtrinsicIndex
    ) -> MultisigPallet.EventTimePoint {
        switch event.eventType {
        case let .approval(approval):
            return approval.timepoint
        case .newMultisig:
            return MultisigPallet.EventTimePoint(
                height: blockNumber,
                index: extrinsicIndex
            )
        }
    }

    func matchAsMultiCallData(
        for callHash: Substrate.CallHash,
        from extrinsicData: Data,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Substrate.CallData? {
        let decoder = try codingFactory.createDecoder(from: extrinsicData)
        let extrinsic: Extrinsic = try decoder.read(of: GenericType.extrinsic.name)

        guard let sender = ExtrinsicExtraction.getSender(
            from: extrinsic,
            codingFactory: codingFactory
        ) else { return nil }

        return try findCall(
            with: callHash,
            in: extrinsic.call,
            sender: sender,
            codingFactory: codingFactory
        )
    }

    func findCall(
        with callHash: Substrate.CallHash,
        in call: JSON,
        sender: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Substrate.CallData? {
        let nestedCallMapper = NestedExtrinsicCallMapper(extrinsicSender: sender)
        let context = codingFactory.createRuntimeJsonContext()

        let maybeCallMappingResult: NestedExtrinsicCallMapResult<RuntimeCall<MultisigPallet.AsMultiCall<JSON>>>
        maybeCallMappingResult = try nestedCallMapper.mapRuntimeCall(
            call: call,
            context: context
        )

        let foundCalls = maybeCallMappingResult.node.calls.map(\.args.call)

        for foundCall in foundCalls {
            let encoder = codingFactory.createEncoder()

            try encoder.append(json: foundCall, type: GenericType.call.name)

            let foundCallData = try encoder.encode()
            let foundCallHash = try foundCallData.blake2b32()

            if callHash == foundCallHash {
                return foundCallData
            }
        }

        return nil
    }
}

// MARK: - MultisigCallFetchFactoryProtocol

extension MultisigCallFetchFactory: MultisigCallFetchFactoryProtocol {
    func createCallFetchWrapper(
        for events: [MultisigEvent],
        at blockHash: Data,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<[Multisig.PendingOperation.Key: MultisigCallFromEvent]> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let blockFetchOperation: JSONRPCOperation<[String], SignedBlock> = JSONRPCOperation(
                engine: connection,
                method: RPCMethod.getChainBlock,
                parameters: [blockHash.toHex(includePrefix: true)]
            )

            let callExtractionOperation = ClosureOperation<[Multisig.PendingOperation.Key: MultisigCallFromEvent]> {
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                let signedBlock = try blockFetchOperation.extractNoCancellableResultData()

                return try self.extractMultisigCalls(
                    from: signedBlock.block,
                    matching: Set(events),
                    chainId: chainId,
                    using: codingFactory
                )
            }

            callExtractionOperation.addDependency(codingFactoryOperation)
            callExtractionOperation.addDependency(blockFetchOperation)

            return CompoundOperationWrapper(
                targetOperation: callExtractionOperation,
                dependencies: [codingFactoryOperation, blockFetchOperation]
            )
        } catch {
            return .createWithError(error)
        }
    }
}
