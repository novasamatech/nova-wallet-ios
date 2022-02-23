import Foundation
import SubstrateSdk
import SoraKeystore

final class DAppSignBytesConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    private(set) var account: ChainAccountResponse?

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) {
        self.request = request
        self.chain = chain
        self.signingWrapperFactory = signingWrapperFactory
    }

    private func validateAndProvideConfirmationModel() {
        guard
            let accountResponse = request.wallet.fetch(for: chain.accountRequest()),
            let chainAddress = accountResponse.toAddress() else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        account = accountResponse

        let networkIconUrl: URL?
        let assetPrecision: UInt16

        if let asset = chain.utilityAssets().first {
            networkIconUrl = asset.icon ?? chain.icon
            assetPrecision = asset.precision
        } else {
            networkIconUrl = nil
            assetPrecision = 0
        }

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletAccountId: request.wallet.substrateAccountId,
            chainAccountId: accountResponse.accountId,
            chainAddress: chainAddress,
            networkName: chain.name,
            utilityAssetPrecision: Int16(bitPattern: assetPrecision),
            dApp: request.dApp,
            dAppIcon: request.dAppIcon,
            networkIcon: networkIconUrl
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
            return try JSONEncoder().encode(request.operationData)
        }
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
            let signer = signingWrapperFactory.createSigningWrapper(
                for: request.wallet.metaId,
                accountResponse: account
            )

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
