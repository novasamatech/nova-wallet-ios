import Foundation
import SubstrateSdk
import Keystore_iOS
import Operation_iOS

final class DAppSignBytesConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let serializationFactory: DAppMessageSignFactoryProtocol
    let operationQueue: OperationQueue

    private(set) var account: ChainAccountResponse?

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        serializationFactory: DAppMessageSignFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.chain = chain
        self.signingWrapperFactory = signingWrapperFactory
        self.serializationFactory = serializationFactory
        self.operationQueue = operationQueue
    }

    private func validateAndProvideConfirmationModel() {
        guard
            let accountResponse = request.wallet.fetchByAccountId(
                request.accountId,
                request: chain.accountRequest()
            ),
            let chainAddress = accountResponse.toAddress() else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        account = accountResponse

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: accountResponse.accountId,
            chainAddress: chainAddress,
            feeAsset: nil,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))
    }

    private func provideZeroFee() {
        let feeModel = FeeOutputModel(value: ExtrinsicFee.zero(), validationProvider: nil)
        presenter?.didReceive(feeResult: .success(feeModel))
        presenter?.didReceive(priceResult: .success(nil))
    }
}

extension DAppSignBytesConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        validateAndProvideConfirmationModel()

        provideZeroFee()
    }

    func estimateFee() {
        provideZeroFee()
    }

    func confirm() {
        guard let account = account else {
            return
        }

        do {
            if let notSupportedSigner = account.type.notSupportedRawBytesSigner {
                throw NoSigningSupportError.notSupported(type: notSupportedSigner)
            }

            let signer = signingWrapperFactory.createSigningWrapper(
                for: request.wallet.metaId,
                accountResponse: account
            )

            let rawBytes = try serializationFactory.serializeSigningMessage(from: request.operationData)

            let signingOperation = ClosureOperation<Data> {
                try signer.sign(rawBytes, context: .rawBytes).rawData()
            }

            signingOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    do {
                        let signature = try signingOperation.extractNoCancellableResultData()

                        let response = DAppOperationResponse(signature: signature, modifiedTransaction: nil)

                        self.presenter?.didReceive(responseResult: .success(response), for: self.request)
                    } catch {
                        self.presenter?.didReceive(responseResult: .failure(error), for: self.request)
                    }
                }
            }

            operationQueue.addOperation(signingOperation)
        } catch {
            presenter?.didReceive(responseResult: .failure(error), for: request)
        }
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil, modifiedTransaction: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
