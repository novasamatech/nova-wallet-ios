import Foundation
import SubstrateSdk
import Keystore_iOS
import Operation_iOS

final class DAppEthereumSignBytesInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let operationQueue: OperationQueue

    private(set) var account: MetaEthereumAccountResponse?

    init(
        request: DAppOperationRequest,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.signingWrapperFactory = signingWrapperFactory
        self.operationQueue = operationQueue
    }

    private func validateAndProvideConfirmationModel() {
        guard
            let accountResponse = request.wallet.fetchEthereum(for: request.accountId),
            let address = try? request.accountId.toAddress(using: .ethereum) else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        account = accountResponse

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: request.accountId,
            chainAddress: address,
            feeAsset: nil,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))
    }

    private func provideZeroFee() {
        let zeroFee = ExtrinsicFee.zero()
        presenter?.didReceive(feeResult: .success(.init(value: zeroFee, validationProvider: nil)))
        presenter?.didReceive(priceResult: .success(nil))
    }

    private func prepareRawBytes() throws -> Data {
        if case let .stringValue(stringValue) = request.operationData {
            if stringValue.isHex() {
                return try Data(hexString: stringValue)
            } else {
                guard let data = stringValue.data(using: .utf8) else {
                    throw CommonError.dataCorruption
                }

                return data
            }

        } else {
            throw CommonError.dataCorruption
        }
    }
}

extension DAppEthereumSignBytesInteractor: DAppOperationConfirmInteractorInputProtocol {
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

            let signer = signingWrapperFactory.createEthereumSigner(for: account)

            let rawBytes = try prepareRawBytes()

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
