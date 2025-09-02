import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

extension DAppOperationConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        processRequestAndContinueSetup(request, chain: chain)

        if let priceId = chain.utilityAssets().first?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func confirm() {
        guard !signCancellable.hasCall, let extrinsicFactory = extrinsicFactory else {
            return
        }

        let signer = signingWrapperFactory.createSigningWrapper(
            for: request.wallet.metaId,
            accountResponse: extrinsicFactory.processedResult.account
        )

        let signWrapper = createSignatureOperation(for: extrinsicFactory, signer: signer)

        executeCancellable(
            wrapper: signWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: signCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let request = self?.request else {
                return
            }

            switch result {
            case let .success(signatureResult):
                let response = DAppOperationResponse(
                    signature: signatureResult.signature,
                    modifiedTransaction: signatureResult.modifiedExtrinsic
                )

                self?.presenter?.didReceive(responseResult: .success(response), for: request)
            case let .failure(error):
                let interactorError: Error
                if let noKeysError = error as? NoKeysSigningWrapperError {
                    interactorError = noKeysError
                } else if let hardwareSigningError = error as? HardwareSigningError {
                    interactorError = hardwareSigningError
                } else if let operationError = error as? DAppOperationConfirmInteractorError {
                    interactorError = operationError
                } else {
                    interactorError = DAppOperationConfirmInteractorError.signingFailed
                }

                self?.presenter?.didReceive(responseResult: .failure(interactorError), for: request)
            }
        }
    }

    func reject() {
        guard !signCancellable.hasCall else {
            return
        }

        let response = DAppOperationResponse(signature: nil, modifiedTransaction: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func estimateFee() {
        guard !feeCancellable.hasCall, let extrinsicFactory = extrinsicFactory else {
            return
        }

        let operationFactory = ExtrinsicProxyOperationFactory(
            proxy: extrinsicFactory,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            feeEstimationRegistry: feeEstimationRegistry,
            operationManager: OperationManager(operationQueue: operationQueue),
            usesStateCallForFee: chain.feeViaRuntimeCall
        )

        let feeWrapper = operationFactory.estimateFeeOperation({ $0 }, payingIn: feeAsset?.chainAssetId)

        executeCancellable(
            wrapper: feeWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: feeCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                // TODO: Consider fee payer here
                let feeModel = FeeOutputModel(value: info, validationProvider: nil)
                self?.presenter?.didReceive(feeResult: .success(feeModel))
            case let .failure(error):
                self?.presenter?.didReceive(feeResult: .failure(error))
            }
        }
    }

    func prepareTxDetails() {
        guard let result = extrinsicFactory?.processedResult else {
            return
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let encodingOperation = ClosureOperation<JSON> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try result.extrinsic.toScaleCompatibleJSON(
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )
        }

        encodingOperation.addDependency(codingFactoryOperation)

        encodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let txDetails = try encodingOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(txDetailsResult: .success(txDetails))
                } catch {
                    self?.presenter?.didReceive(txDetailsResult: .failure(error))
                }
            }
        }

        operationQueue.addOperations([codingFactoryOperation, encodingOperation], waitUntilFinished: false)
    }
}

extension DAppOperationConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceive(priceResult: result)
    }
}

extension DAppOperationConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chain.utilityAssets().first?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
