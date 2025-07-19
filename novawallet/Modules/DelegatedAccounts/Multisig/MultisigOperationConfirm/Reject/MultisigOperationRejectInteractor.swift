import Foundation
import SubstrateSdk

final class MultisigOperationRejectInteractor: MultisigOperationConfirmInteractor {
    let feeCallStore = CancellableCallStore()

    deinit {
        feeCallStore.cancel()
    }

    override func didSetupSignatories() {
        doEstimateFee()
    }

    override func didUpdateOperation() {
        doEstimateFee()
    }

    override func didProcessCall() {
        logger.debug("Did process call")
    }

    override func doConfirm(with definition: MultisigPallet.MultisigDefinition) {
        guard
            let multisig = multisigWallet.getMultisig(for: chain),
            let extrinsicSubmissionMonitor,
            let signer else {
            return
        }

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            timepoint: definition.timepoint,
            callHash: operation.operation.callHash
        )

        let submissionWrapper = extrinsicSubmissionMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: builderClosure,
            signer: signer
        )

        execute(
            wrapper: submissionWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didCompleteSubmission(
                    with: model.extrinsicSubmittedModel,
                    submissionType: .reject
                )
            case let .failure(error):
                self?.presenter?.didReceiveError(.submissionError(error))
            }
        }
    }

    override func doEstimateFee() {
        guard
            let multisig = multisigWallet.getMultisig(for: chain),
            let definition = operation.operation.multisigDefinition,
            let operationFactory = extrinsicOperationFactory else {
            return
        }

        feeCallStore.cancel()

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            timepoint: definition.timepoint.toSubmissionModel(),
            callHash: operation.operation.callHash
        )

        let feeWrapper = operationFactory.estimateFeeOperation(builderClosure)

        executeCancellable(
            wrapper: feeWrapper,
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
}

// MARK: - Private

private extension MultisigOperationRejectInteractor {
    func createExtrinsicClosure(
        for multisig: DelegatedAccount.MultisigAccountModel,
        timepoint: MultisigPallet.MultisigTimepoint,
        callHash: Substrate.CallHash
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let otherSignatories = multisig.getOtherSignatoriesInOrder().map {
                BytesCodable(wrappedValue: $0)
            }

            let wrappedCall = MultisigPallet.CancelAsMultiCall(
                threshold: UInt16(multisig.threshold),
                otherSignatories: otherSignatories,
                timepoint: timepoint,
                callHash: callHash
            ).runtimeCall()

            return try builder.adding(call: wrappedCall)
        }
    }
}
