import Foundation
import SubstrateSdk
import SoraKeystore

final class DAppEthereumSignBytesInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    private(set) var account: MetaEthereumAccountResponse?

    init(
        request: DAppOperationRequest,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) {
        self.request = request
        self.signingWrapperFactory = signingWrapperFactory
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
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))
    }

    private func provideZeroFee() {
        let fee = RuntimeDispatchInfo(fee: "0", weight: 0)

        presenter?.didReceive(feeResult: .success(fee))
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

            let signature = try signer.sign(rawBytes).rawData()

            let response = DAppOperationResponse(signature: signature)

            presenter?.didReceive(responseResult: .success(response), for: request)
        } catch {
            presenter?.didReceive(responseResult: .failure(error), for: request)
        }
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
