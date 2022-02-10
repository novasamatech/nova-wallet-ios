import Foundation
import RobinHood
import SubstrateSdk

extension DAppOperationConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        processRequestAndContinueSetup(request, chain: chain)

        if let priceId = chain.utilityAssets().first?.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }

    func confirm() {
        guard signWrapper == nil, let result = processedResult else {
            return
        }

        let signer = signingWrapperFactory.createSigningWrapper(
            for: request.wallet.metaId,
            accountResponse: result.account
        )

        let signWrapper = createSignatureOperation(for: result, signer: signer)

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
                    let interactorError = error as? DAppOperationConfirmInteractorError ?? .signingFailed
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
        guard feeWrapper == nil, let result = processedResult else {
            return
        }

        guard let signer = try? DummySigner(cryptoType: result.account.cryptoType) else {
            return
        }

        let builderWrapper = createFeePayloadOperation(
            for: result,
            signer: signer
        )

        let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(
            engine: connection,
            method: RPCMethod.paymentInfo
        )

        infoOperation.configurationBlock = {
            do {
                let payload = try builderWrapper.targetOperation.extractNoCancellableResultData()
                let extrinsic = payload.toHex(includePrefix: true)
                infoOperation.parameters = [extrinsic]
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(builderWrapper.targetOperation)

        infoOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.feeWrapper != nil else {
                    return
                }

                self?.feeWrapper = nil

                do {
                    let info = try infoOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(feeResult: .success(info))
                } catch {
                    self?.presenter?.didReceive(feeResult: .failure(error))
                }
            }
        }

        let feeWrapper = CompoundOperationWrapper(
            targetOperation: infoOperation,
            dependencies: builderWrapper.allOperations
        )

        self.feeWrapper = feeWrapper

        operationQueue.addOperations(feeWrapper.allOperations, waitUntilFinished: false)
    }

    func prepareTxDetails() {
        guard let result = processedResult else {
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
