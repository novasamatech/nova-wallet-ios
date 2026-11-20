import Foundation
import SubstrateSdk
import Operation_iOS

final class DAppCreateTransactionConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel
    let account: ChainAccountResponse

    let extrinsicFactory: DAppTxPayloadExtrinsicOperationFactoryProtocol
    let feeOperationFactory: ExtrinsicOperationFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var processedResult: DAppTxPayloadProcessedResult?

    // Set once the payload has failed the verification: nothing can be signed and the dApp gets this as the result
    private var verificationError: DAppCreateTransactionError?

    // Set when the request couldn't be prepared for a reason the dApp isn't responsible for
    private var setupError: Error?

    private var priceProvider: StreamableProvider<PriceData>?
    private let processingCallStore = CancellableCallStore()
    private let feeCallStore = CancellableCallStore()
    private let signCallStore = CancellableCallStore()

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        account: ChainAccountResponse,
        extrinsicFactory: DAppTxPayloadExtrinsicOperationFactoryProtocol,
        feeOperationFactory: ExtrinsicOperationFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        priceProviderFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.chain = chain
        self.account = account
        self.extrinsicFactory = extrinsicFactory
        self.feeOperationFactory = feeOperationFactory
        self.signingWrapperFactory = signingWrapperFactory
        priceLocalSubscriptionFactory = priceProviderFactory
        self.operationQueue = operationQueue
        super.init()

        self.currencyManager = currencyManager
    }

    deinit {
        processingCallStore.cancel()
        feeCallStore.cancel()
        signCallStore.cancel()
    }
}

// MARK: Private

private extension DAppCreateTransactionConfirmInteractor {
    func completeSetup(with result: DAppTxPayloadProcessedResult) {
        processedResult = result
        setupError = nil

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: account.accountId,
            chainAddress: account.toAddress() ?? "",
            feeAsset: result.payment.feeAsset,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        subscribePrice()
        estimateFee()
    }

    func subscribePrice() {
        let feeAsset = processedResult?.payment.feeAsset?.asset ?? chain.utilityAssets().first

        guard let priceId = feeAsset?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func handleFailure(_ error: Error, fallback: (Error) -> Void) {
        guard let verificationError = error as? DAppCreateTransactionError else {
            fallback(error)
            return
        }

        self.verificationError = verificationError

        provideNoFee()
        presenter?.didReceive(modelResult: .failure(verificationError))
    }

    func handleSetupFailure(_ error: Error) {
        setupError = error

        provideNoFee()
        presenter?.didReceive(
            modelResult: .failure(DAppOperationConfirmInteractorError.requestNotPrepared(reason: error))
        )
    }

    // Nothing is going to be estimated any more: without an answer the fee row would keep loading
    func provideNoFee() {
        let feeModel = FeeOutputModel(value: ExtrinsicFee.zero(), validationProvider: nil)
        presenter?.didReceive(feeResult: .success(feeModel))
    }

    func respond(with result: Result<Data, DAppCreateTransactionError>) {
        let response = DAppOperationResponse(createTransactionResult: result)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func handleSigning(result: Result<ExtrinsicsCreationResult, Error>) {
        switch result {
        case let .success(creationResult):
            guard let extrinsic = creationResult.extrinsics.first else {
                let error = DAppOperationConfirmInteractorError.signingFailed
                presenter?.didReceive(responseResult: .failure(error), for: request)
                return
            }

            respond(with: .success(extrinsic))
        case let .failure(error):
            if let verificationError = error as? DAppCreateTransactionError {
                respond(with: .failure(verificationError))
            } else {
                let interactorError = DAppOperationConfirmInteractorError.signingError(from: error)
                presenter?.didReceive(responseResult: .failure(interactorError), for: request)
            }
        }
    }
}

// MARK: DAppOperationConfirmInteractorInputProtocol

extension DAppCreateTransactionConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        executeCancellable(
            wrapper: extrinsicFactory.createProcessingWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: processingCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(processedResult):
                self?.completeSetup(with: processedResult)
            case let .failure(error):
                self?.handleFailure(error) { error in
                    self?.handleSetupFailure(error)
                }
            }
        }
    }

    func estimateFee() {
        guard !feeCallStore.hasCall, let processedResult else {
            return
        }

        let feeWrapper = feeOperationFactory.estimateFeeOperation(
            { $0 },
            payingIn: processedResult.payment.feeAsset?.chainAssetId
        )

        executeCancellable(
            wrapper: feeWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: feeCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fee):
                let feeModel = FeeOutputModel(value: fee, validationProvider: nil)
                self?.presenter?.didReceive(feeResult: .success(feeModel))
            case let .failure(error):
                // the signer is resolved while the extrinsic is built, so its refusal arrives with the fee
                self?.handleFailure(error) { error in
                    self?.presenter?.didReceive(feeResult: .failure(error))
                }
            }
        }
    }

    func confirm() {
        guard !signCallStore.hasCall else {
            return
        }

        if let verificationError {
            respond(with: .failure(verificationError))
            return
        }

        guard let processedResult else {
            // no payload is verified, so nothing can be signed: the tap is answered with the reason
            let error = DAppOperationConfirmInteractorError.requestNotPrepared(reason: setupError)
            presenter?.didReceive(modelResult: .failure(error))
            return
        }

        let signer = signingWrapperFactory.createSigningWrapper(
            for: request.wallet.metaId,
            accountResponse: account
        )

        let extrinsicWrapper = extrinsicFactory.createWrapper(
            customClosure: { builder, _ in builder },
            indexes: [0],
            payingFeeIn: processedResult.payment.feeAsset?.chainAssetId,
            signingClosure: { data, context in
                try signer.sign(data, context: context).rawData()
            }
        )

        executeCancellable(
            wrapper: extrinsicWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: signCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.handleSigning(result: result)
        }
    }

    func reject() {
        guard !signCallStore.hasCall else {
            return
        }

        if let verificationError {
            respond(with: .failure(verificationError))
        } else {
            let response = DAppOperationResponse(signature: nil, modifiedTransaction: nil)
            presenter?.didReceive(responseResult: .success(response), for: request)
        }
    }

    func prepareTxDetails() {
        guard let processedResult else {
            presenter?.didReceive(txDetailsResult: .success(request.operationData))
            return
        }

        let details = DAppTxPayloadDetails(
            resolution: processedResult.resolution,
            signer: account.toAddress() ?? ""
        )

        presenter?.didReceive(txDetailsResult: Result { try details.toScaleCompatibleJSON() })
    }
}

extension DAppCreateTransactionConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceive(priceResult: result)
    }
}

extension DAppCreateTransactionConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        subscribePrice()
    }
}
