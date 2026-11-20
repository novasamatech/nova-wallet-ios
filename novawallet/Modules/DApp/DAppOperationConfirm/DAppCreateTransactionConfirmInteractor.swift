import Foundation
import SubstrateSdk

final class DAppCreateTransactionConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel

    init(request: DAppOperationRequest, chain: ChainModel) {
        self.request = request
        self.chain = chain
    }
}

// MARK: Private

private extension DAppCreateTransactionConfirmInteractor {
    func createConfirmationModel() throws -> DAppOperationConfirmModel {
        let payload = try request.operationData.map(to: PolkadotExtensionTxPayload.self)

        // The confirmation shows the chain of the request, so the payload must target the same one
        guard try Data(hexString: payload.context.genesisHash).toHex() == chain.chainId else {
            throw DAppCreateTransactionError.decodeError(details: "genesis hash doesn't match the chain")
        }

        guard
            let account = request.wallet.fetchByAccountId(request.accountId, request: chain.accountRequest()),
            let chainAddress = account.toAddress() else {
            throw ChainAccountFetchingError.accountNotExists
        }

        return DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: account.accountId,
            chainAddress: chainAddress,
            feeAsset: nil,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )
    }

    func provideZeroFee() {
        let feeModel = FeeOutputModel(value: ExtrinsicFee.zero(), validationProvider: nil)
        presenter?.didReceive(feeResult: .success(feeModel))
        presenter?.didReceive(priceResult: .success(nil))
    }
}

// MARK: DAppOperationConfirmInteractorInputProtocol

extension DAppCreateTransactionConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        let modelResult = Result { try createConfirmationModel() }
        presenter?.didReceive(modelResult: modelResult)

        provideZeroFee()
    }

    func estimateFee() {
        provideZeroFee()
    }

    func confirm() {
        // TODO: NW-2378 build, sign and return the extrinsic once the payload verification on substrate-sdk 5 lands
        let error = DAppCreateTransactionError.signerUnavailable(details: "createTransaction is not supported yet")
        let response = DAppOperationResponse(createTransactionResult: .failure(error))
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil, modifiedTransaction: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
