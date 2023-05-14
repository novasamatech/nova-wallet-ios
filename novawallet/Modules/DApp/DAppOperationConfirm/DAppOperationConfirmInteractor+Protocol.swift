import Foundation
import RobinHood
import SubstrateSdk

extension DAppOperationConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        processRequestAndContinueSetup(request, chain: chain)

        if let priceId = chain.utilityAssets().first?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func confirm() {
        guard signWrapper == nil, let extrinsicFactory = extrinsicFactory else {
            return
        }

        let signer = signingWrapperFactory.createSigningWrapper(
            for: request.wallet.metaId,
            accountResponse: extrinsicFactory.processedResult.account
        )

        let signWrapper = createSignatureOperation(for: extrinsicFactory, signer: signer)

        self.signWrapper = signWrapper

        signWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.signWrapper != nil else {
                    return
                }

                self?.signWrapper = nil

                guard let request = self?.request else {
                    return
                }

                do {
                    let signature = try signWrapper.targetOperation.extractNoCancellableResultData()
                    let response = DAppOperationResponse(signature: signature)
                    self?.presenter?.didReceive(responseResult: .success(response), for: request)
                } catch {
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

        operationQueue.addOperations(signWrapper.allOperations, waitUntilFinished: false)
    }

    func reject() {
        guard signWrapper == nil else {
            return
        }

        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func estimateFee() {
        guard feeWrapper == nil, let extrinsicFactory = extrinsicFactory else {
            return
        }

        let operationFactory = ExtrinsicProxyOperationFactory(
            proxy: extrinsicFactory,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let feeWrapper = operationFactory.estimateFeeOperation { builder in
            builder
        }

        feeWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.feeWrapper != nil else {
                    return
                }

                self?.feeWrapper = nil

                do {
                    let info = try feeWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(feeResult: .success(info))
                } catch {
                    self?.presenter?.didReceive(feeResult: .failure(error))
                }
            }
        }

        self.feeWrapper = feeWrapper

        operationQueue.addOperations(feeWrapper.allOperations, waitUntilFinished: false)
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
