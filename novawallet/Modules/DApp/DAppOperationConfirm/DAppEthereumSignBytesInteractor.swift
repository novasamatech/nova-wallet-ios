import Foundation
import SubstrateSdk
import SoraKeystore

final class DAppEthereumSignBytesInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: MetamaskChain
    let accountId: AccountId
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    private(set) var account: MetaEthereumAccountResponse?

    init(
        request: DAppOperationRequest,
        accountId: AccountId,
        chain: MetamaskChain,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) {
        self.request = request
        self.accountId = accountId
        self.chain = chain
        self.signingWrapperFactory = signingWrapperFactory
    }

    private func validateAndProvideConfirmationModel() {
        guard
            let accountResponse = request.wallet.fetchEthereum(for: accountId),
            let address = try? accountId.toAddress(using: .ethereum) else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        account = accountResponse

        let iconUrl: URL?

        if let urlString = chain.iconUrls?.first, let url = URL(string: urlString) {
            iconUrl = url
        } else {
            iconUrl = nil
        }

        let assetPrecision = chain.nativeCurrency.decimals

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: accountId,
            chainAddress: address,
            networkName: chain.chainName,
            utilityAssetPrecision: assetPrecision,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon,
            networkIcon: iconUrl
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))
    }

    private func provideZeroFee() {
        let fee = RuntimeDispatchInfo(dispatchClass: "Fee", fee: "0", weight: 0)

        presenter?.didReceive(feeResult: .success(fee))
        presenter?.didReceive(priceResult: .success(nil))
    }

    private func prepareRawBytes() throws -> Data {
        if case let .stringValue(hexValue) = request.operationData {
            return try Data(hexString: hexValue)
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
            guard account.type.supportsSigningRawBytes else {
                throw NoSigningSupportError.notSupported
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
