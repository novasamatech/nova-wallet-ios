import Foundation
import Operation_iOS
import SubstrateSdk

final class MultisigOperationApproveInteractor: MultisigOperationConfirmInteractor {
    let callWeightEstimator: CallWeightEstimatingFactoryProtocol

    let feeCallStore = CancellableCallStore()

    private var callWeight: Substrate.Weight?

    init(
        operation: Multisig.PendingOperationProxyModel,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        operationChainAsset: ChainAsset?,
        remoteOperationFactory: MultisigStorageOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        balanceRemoteSubscriptionFactory: WalletRemoteSubscriptionWrapperProtocol,
        signatoryRepository: MultisigSignatoryRepositoryProtocol,
        pendingOperationProvider: MultisigOperationProviderProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        callWeightEstimator: CallWeightEstimatingFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.callWeightEstimator = callWeightEstimator

        super.init(
            operation: operation,
            chain: chain,
            multisigWallet: multisigWallet,
            operationChainAsset: operationChainAsset,
            remoteOperationFactory: remoteOperationFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            balanceRemoteSubscriptionFactory: balanceRemoteSubscriptionFactory,
            signatoryRepository: signatoryRepository,
            pendingOperationProvider: pendingOperationProvider,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: signingWrapperFactory,
            assetInfoOperationFactory: assetInfoOperationFactory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            currencyManager: currencyManager,
            logger: logger
        )
    }

    override func didSetupSignatories() {
        doEstimateFee()
    }

    override func didUpdateOperation() {
        doEstimateFee()
    }

    override func didProcessCall() {
        logger.debug("Did process call")

        doEstimateFee()
    }

    override func doEstimateFee() {
        guard
            let call,
            let multisig = multisigWallet.getMultisig(for: chain),
            let definition = operation.operation.multisigDefinition,
            let operationFactory = extrinsicOperationFactory else {
            return
        }

        feeCallStore.cancel()

        let callWeightWrapper = fetchCallWeight()

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            timepoint: definition.timepoint.toSubmissionModel(),
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

    override func doConfirm(with definition: MultisigPallet.MultisigDefinition) {
        guard
            let call,
            let multisig = multisigWallet.getMultisig(for: chain),
            let extrinsicSubmissionMonitor,
            let signer else {
            return
        }

        let callWeightWrapper = fetchCallWeight()

        let builderClosure = createExtrinsicClosure(
            for: multisig,
            timepoint: definition.timepoint,
            call: call,
            callWeightClosure: {
                try callWeightWrapper.targetOperation.extractNoCancellableResultData()
            }
        )

        let submissionWrapper = extrinsicSubmissionMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: builderClosure,
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
            case let .success(model):
                self?.presenter?.didCompleteSubmission(
                    with: model.extrinsicSubmittedModel,
                    submissionType: .approve
                )
            case let .failure(error):
                self?.presenter?.didReceiveError(.submissionError(error))
            }
        }
    }
}

// MARK: - Private

private extension MultisigOperationApproveInteractor {
    func createExtrinsicClosure(
        for multisig: DelegatedAccount.MultisigAccountModel,
        timepoint: MultisigPallet.MultisigTimepoint,
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
                maybeTimepoint: timepoint,
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
