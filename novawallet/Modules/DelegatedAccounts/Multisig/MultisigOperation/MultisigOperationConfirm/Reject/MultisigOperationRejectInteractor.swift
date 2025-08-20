import Foundation
import SubstrateSdk
import Operation_iOS

final class MultisigOperationRejectInteractor: MultisigOperationConfirmInteractor {
    let settingsRepository: AnyDataProviderRepository<DelegatedAccountSettings>

    let feeCallStore = CancellableCallStore()

    init(
        settingsRepository: AnyDataProviderRepository<DelegatedAccountSettings>,
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
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.settingsRepository = settingsRepository

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

    deinit {
        feeCallStore.cancel()
    }

    override func setup() {
        super.setup()

        provideSettings()
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
    func provideSettings() {
        let metaId = multisigWallet.metaId

        let fetchOperation = settingsRepository.fetchOperation(
            by: { metaId },
            options: .init(includesProperties: true, includesSubentities: true)
        )

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(settings):
                self?.presenter?.didReceive(needsConfirmation: settings?.confirmsOperation ?? true)
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
            }
        }
    }

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
