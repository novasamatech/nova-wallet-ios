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

    override func doConfirm() {
        guard
            let multisig = multisigWallet.multisigAccount?.multisig,
            let definition = operation.operation.multisigDefinition,
            let extrinsicSubmissionMonitor,
            let signer else {
            return
        }

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            definition: definition,
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
            case .success:
                self?.presenter?.didCompleteSubmission(with: .reject)
            case let .failure(error):
                self?.presenter?.didReceiveError(.submissionError(error))
            }
        }
    }

    override func doEstimateFee() {
        guard
            let multisig = multisigWallet.multisigAccount?.multisig,
            let definition = operation.operation.multisigDefinition,
            let operationFactory = extrinsicOperationFactory else {
            return
        }

        feeCallStore.cancel()

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            definition: definition,
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
        definition: Multisig.MultisigDefinition,
        callHash: Substrate.CallHash
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let otherSignatories = multisig.getOtherSignatoriesInOrder().map {
                BytesCodable(wrappedValue: $0)
            }

            let wrappedCall = MultisigPallet.CancelAsMultiCall(
                threshold: UInt16(multisig.threshold),
                otherSignatories: otherSignatories,
                timepoint: definition.timepoint.toSubmissionModel(),
                callHash: callHash
            ).runtimeCall()

            return try builder.adding(call: wrappedCall)
        }
    }
}
