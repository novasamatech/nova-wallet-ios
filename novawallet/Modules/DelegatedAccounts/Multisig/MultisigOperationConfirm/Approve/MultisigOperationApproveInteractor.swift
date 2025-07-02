import Foundation
import Operation_iOS
import SubstrateSdk

final class MultisigOperationApproveInteractor: MultisigOperationConfirmInteractor {
    let callWeightEstimator: CallWeightEstimatingFactoryProtocol

    let feeCallStore = CancellableCallStore()

    private var callWeight: Substrate.Weight?

    init(
        operation: Multisig.PendingOperation,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        signatoryRepository: MultisigSignatoryRepositoryProtocol,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        callWeightEstimator: CallWeightEstimatingFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.callWeightEstimator = callWeightEstimator

        super.init(
            operation: operation,
            chain: chain,
            multisigWallet: multisigWallet,
            signatoryRepository: signatoryRepository,
            pendingMultisigLocalSubscriptionFactory: pendingMultisigLocalSubscriptionFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: signingWrapperFactory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    override func didSetupSignatories() {
        estimateFee()
    }

    override func didUpdateOperation() {
        estimateFee()
    }

    override func didProcessCall() {
        logger.debug("Did process call")

        estimateFee()
    }

    override func doConfirm() {
        guard
            let call,
            let multisig = multisigWallet.multisigAccount?.multisig,
            let definition = operation.multisigDefinition,
            let extrinsicOperationFactory,
            let signer else {
            return
        }

        let callWeightWrapper = fetchCallWeight()

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            definition: definition,
            call: call,
            callWeightClosure: {
                try callWeightWrapper.targetOperation.extractNoCancellableResultData()
            }
        )

        let submissionWrapper = extrinsicOperationFactory.submit(
            builderClosure,
            signer: signer
        )

        submissionWrapper.addDependency(wrapper: callWeightWrapper)

        let totalWrapper = submissionWrapper.insertingHead(operations: callWeightWrapper.allOperations)

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didCompleteSubmission()
            case let .failure(error):
                self?.presenter?.didReceiveError(.submissionError(error))
            }
        }
    }
}

private extension MultisigOperationApproveInteractor {
    func estimateFee() {
        guard
            let call,
            let multisig = multisigWallet.multisigAccount?.multisig,
            let definition = operation.multisigDefinition,
            let operationFactory = extrinsicOperationFactory else {
            return
        }

        feeCallStore.cancel()

        let callWeightWrapper = fetchCallWeight()

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            definition: definition,
            call: call,
            callWeightClosure: {
                try callWeightWrapper.targetOperation.extractNoCancellableResultData()
            }
        )

        let feeWrapper = operationFactory.estimateFeeOperation(builderClosure)

        feeWrapper.addDependency(wrapper: callWeightWrapper)

        let totalWrapper = feeWrapper.insertingHead(operations: callWeightWrapper.allOperations)

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: feeCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fee):
                self?.presenter?.didReceiveFee(fee)
            case let .failure(error):
                self?.presenter?.didReceiveError(.feeError(error))
            }
        }
    }

    func createExtrinsicClosure(
        for multisig: DelegatedAccount.MultisigAccountModel,
        definition: Multisig.MultisigDefinition,
        call: AnyRuntimeCall,
        callWeightClosure: @escaping () throws -> Substrate.Weight
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let weight = try callWeightClosure()
            let otherSignatories = multisig.getOtherSignatoriesInOrder().map {
                BytesCodable(wrappedValue: $0)
            }

            let wrappedCall = MultisigPallet.AsMultiCall(
                threshold: UInt16(multisig.threshold),
                otherSignatories: otherSignatories,
                maybeTimepoint: definition.timepoint.toSubmissionModel(),
                call: call,
                maxWeight: weight
            ).runtimeCall()

            return try builder.adding(call: wrappedCall)
        }
    }

    func fetchCallWeight() -> CompoundOperationWrapper<Substrate.Weight> {
        if let callWeight {
            return .createWithResult(callWeight)
        }

        guard let call else {
            return .createWithError(MultisigOperationApproveInteractorError.missingCall)
        }

        let operationFactory = extrinsicServiceFactory.createOperationFactoryForWeightEstimation(on: chain)

        return callWeightEstimator.estimateWeight(
            of: RuntimeCallCollector(call: call),
            operationFactory: operationFactory
        )
    }
}
