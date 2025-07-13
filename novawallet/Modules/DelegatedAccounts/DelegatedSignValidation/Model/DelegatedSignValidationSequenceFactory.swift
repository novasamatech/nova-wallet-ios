import Foundation
import SubstrateSdk
import Operation_iOS

protocol DSValidationSequenceFactoryProtocol {
    func createWrapper(
        for call: JSON,
        extrinsicSender: MetaChainAccountResponse,
        unwrappedCallOrigin: ChainAccountResponse,
        resolvedPath: DelegationResolution.PathFinderPath,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DelegatedSignValidationSequence>
}

enum DSValidationSequenceFactoryError: Error {
    case unexpectedDelegationType(depth: Int, type: DelegationType)
    case unexpectedEndOfChain(depth: Int)
}

final class DSValidationSequenceFactory {
    struct ProcessingData {
        let extrinsicSender: MetaChainAccountResponse
        let unwrappedCallOrigin: ChainAccountResponse
        let currentCall: AnyRuntimeCall

        func replacing(call: AnyRuntimeCall) -> ProcessingData {
            .init(
                extrinsicSender: extrinsicSender,
                unwrappedCallOrigin: unwrappedCallOrigin,
                currentCall: call
            )
        }
    }

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

private extension DSValidationSequenceFactory {
    func process(
        processingData: ProcessingData,
        depth: Int,
        sequenceBuilder: DelegatedSignValidationSequenceBuilder,
        resolvedPath: [DelegationResolution.PathFinderPath.Component],
        context: RuntimeJsonContext
    ) throws {
        switch processingData.currentCall.path {
        case MultisigPallet.asMultiPath:
            try processAsMulti(
                processingData: processingData,
                depth: depth,
                sequenceBuilder: sequenceBuilder,
                resolvedPath: resolvedPath,
                context: context
            )
        case MultisigPallet.asMultiThreshold1Path:
            try processAsMultiThreshold1(
                processingData: processingData,
                depth: depth,
                sequenceBuilder: sequenceBuilder,
                resolvedPath: resolvedPath,
                context: context
            )
        case Proxy.ProxyCall.callPath:
            try processProxy(
                processingData: processingData,
                depth: depth,
                sequenceBuilder: sequenceBuilder,
                resolvedPath: resolvedPath,
                context: context
            )
        default:
            guard
                depth == resolvedPath.count else {
                throw DSValidationSequenceFactoryError.unexpectedDelegationType(
                    depth: depth,
                    type: resolvedPath[depth].delegationValue.delegationType
                )

                return
            }

            if depth == 0 {
                addConfirmationNode(
                    of: .proxy,
                    call: processingData.currentCall,
                    sender: processingData.extrinsicSender,
                    sequenceBuilder: sequenceBuilder
                )

                addFeeNode(
                    of: .proxy,
                    call: processingData.currentCall,
                    sender: processingData.extrinsicSender,
                    sequenceBuilder: sequenceBuilder
                )
            }
        }
    }

    func processAsMulti(
        processingData: ProcessingData,
        depth: Int,
        sequenceBuilder: DelegatedSignValidationSequenceBuilder,
        resolvedPath: [DelegationResolution.PathFinderPath.Component],
        context: RuntimeJsonContext
    ) throws {
        try ensureDelegationClass(
            depth: depth,
            resolvedPath: resolvedPath,
            expectedClass: .multisig
        )

        guard depth < resolvedPath.count else {
            return
        }

        let callSender = resolvedPath[depth].account

        let callOrigin: ChainAccountResponse = if depth + 1 < resolvedPath.count - 1 {
            resolvedPath[depth + 1].account.chainAccount
        } else {
            processingData.unwrappedCallOrigin
        }

        let callArgs = try processingData.currentCall.args.map(
            to: MultisigPallet.AsMultiCall<AnyRuntimeCall>.self,
            with: context.toRawContext()
        )

        try process(
            processingData: processingData.replacing(call: callArgs.call),
            depth: depth + 1,
            sequenceBuilder: sequenceBuilder,
            resolvedPath: resolvedPath,
            context: context
        )

        addConfirmationNode(
            of: .multisig,
            call: callArgs.call,
            sender: callSender,
            sequenceBuilder: sequenceBuilder
        )

        let validationNode = DelegatedSignValidationSequence.MultisigOperationNode(
            signatory: callSender,
            call: callArgs.runtimeCall(),
            multisig: callOrigin
        )

        sequenceBuilder.adding(node: .multisigOperation(validationNode))

        if depth == 0 {
            addFeeNode(
                of: .multisig,
                call: processingData.currentCall,
                sender: callSender,
                sequenceBuilder: sequenceBuilder
            )
        }
    }

    func processAsMultiThreshold1(
        processingData: ProcessingData,
        depth: Int,
        sequenceBuilder: DelegatedSignValidationSequenceBuilder,
        resolvedPath: [DelegationResolution.PathFinderPath.Component],
        context: RuntimeJsonContext
    ) throws {
        try ensureDelegationClass(
            depth: depth,
            resolvedPath: resolvedPath,
            expectedClass: .multisig
        )

        guard depth < resolvedPath.count else {
            return
        }

        let callSender = resolvedPath[depth].account

        let callArgs = try processingData.currentCall.args.map(
            to: MultisigPallet.AsMultiThreshold1Call<AnyRuntimeCall>.self,
            with: context.toRawContext()
        )

        try process(
            processingData: processingData.replacing(call: callArgs.call),
            depth: depth + 1,
            sequenceBuilder: sequenceBuilder,
            resolvedPath: resolvedPath,
            context: context
        )

        if depth == 0 {
            addFeeNode(
                of: .multisig,
                call: processingData.currentCall,
                sender: callSender,
                sequenceBuilder: sequenceBuilder
            )
        }
    }

    func processProxy(
        processingData: ProcessingData,
        depth: Int,
        sequenceBuilder: DelegatedSignValidationSequenceBuilder,
        resolvedPath: [DelegationResolution.PathFinderPath.Component],
        context: RuntimeJsonContext
    ) throws {
        try ensureDelegationClass(
            depth: depth,
            resolvedPath: resolvedPath,
            expectedClass: .proxy
        )

        guard depth < resolvedPath.count else {
            return
        }

        let callSender = resolvedPath[depth].account

        let callArgs = try processingData.currentCall.args.map(
            to: Proxy.ProxyCall.self,
            with: context.toRawContext()
        )

        let nestedCall = try callArgs.call.map(
            to: AnyRuntimeCall.self,
            with: context.toRawContext()
        )

        try process(
            processingData: processingData.replacing(call: nestedCall),
            depth: depth + 1,
            sequenceBuilder: sequenceBuilder,
            resolvedPath: resolvedPath,
            context: context
        )

        if depth == 0 {
            addConfirmationNode(
                of: .proxy,
                call: processingData.currentCall,
                sender: callSender,
                sequenceBuilder: sequenceBuilder
            )

            addFeeNode(
                of: .proxy,
                call: processingData.currentCall,
                sender: callSender,
                sequenceBuilder: sequenceBuilder
            )
        }
    }

    func addFeeNode(
        of delegationClass: DelegationClass,
        call: AnyRuntimeCall,
        sender: MetaChainAccountResponse,
        sequenceBuilder: DelegatedSignValidationSequenceBuilder
    ) {
        let feeNode = DelegatedSignValidationSequence.FeeNode(
            account: sender,
            call: call,
            delegationClass: delegationClass
        )

        sequenceBuilder.adding(node: .fee(feeNode))
    }

    func addConfirmationNode(
        of delegationClass: DelegationClass,
        call: AnyRuntimeCall,
        sender: MetaChainAccountResponse,
        sequenceBuilder: DelegatedSignValidationSequenceBuilder
    ) {
        let feeNode = DelegatedSignValidationSequence.OperationConfirmNode(
            account: sender,
            call: call,
            delegationClass: delegationClass
        )

        sequenceBuilder.adding(node: .confirmation(feeNode))
    }

    func ensureDelegationClass(
        depth: Int,
        resolvedPath: [DelegationResolution.PathFinderPath.Component],
        expectedClass: DelegationClass
    ) throws {
        guard depth < resolvedPath.count else {
            throw DSValidationSequenceFactoryError.unexpectedEndOfChain(depth: depth)
        }

        let delegationType = resolvedPath[depth].delegationValue.delegationType

        if delegationType.delegationClass != expectedClass {
            throw DSValidationSequenceFactoryError.unexpectedDelegationType(
                depth: depth,
                type: delegationType
            )
        }
    }
}

extension DSValidationSequenceFactory: DSValidationSequenceFactoryProtocol {
    func createWrapper(
        for call: JSON,
        extrinsicSender: MetaChainAccountResponse,
        unwrappedCallOrigin: ChainAccountResponse,
        resolvedPath: DelegationResolution.PathFinderPath,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DelegatedSignValidationSequence> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let parsingOperation = ClosureOperation<DelegatedSignValidationSequence> {
                let coderFactory = try coderFactoryOperation.extractNoCancellableResultData()
                let context = coderFactory.createRuntimeJsonContext()

                let runtimeCall = try call.map(to: AnyRuntimeCall.self, with: context.toRawContext())
                let builder = DelegatedSignValidationSequenceBuilder()

                // the call is unwrapped top down but components are from bottom to top
                let components = resolvedPath.components.reversed()

                let processingData = ProcessingData(
                    extrinsicSender: extrinsicSender,
                    unwrappedCallOrigin: unwrappedCallOrigin,
                    currentCall: runtimeCall
                )

                try self.process(
                    processingData: processingData,
                    depth: 0,
                    sequenceBuilder: builder,
                    resolvedPath: Array(components),
                    context: context
                )

                return builder.build()
            }

            parsingOperation.addDependency(coderFactoryOperation)

            return CompoundOperationWrapper(
                targetOperation: parsingOperation,
                dependencies: [coderFactoryOperation]
            )

        } catch {
            return .createWithError(error)
        }
    }
}
