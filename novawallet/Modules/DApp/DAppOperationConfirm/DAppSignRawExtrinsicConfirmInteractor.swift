import Foundation
import SubstrateSdk
import SoraKeystore
import RobinHood

final class DAppSignRawExtrinsicConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let operationQueue: OperationQueue
    let runtimeProvider: RuntimeProviderProtocol

    private(set) var account: ChainAccountResponse?

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.chain = chain
        self.signingWrapperFactory = signingWrapperFactory
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
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

    private func wrapSignatureAndComplete(
        _ signature: Data,
        account: ChainAccountResponse,
        request: DAppOperationRequest
    ) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let signatureOperation = ClosureOperation<Data> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let scaleEncoder = codingFactory.createEncoder()

            switch account.cryptoType {
            case .sr25519:
                try scaleEncoder.append(
                    MultiSignature.sr25519(data: signature),
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            case .ed25519:
                try scaleEncoder.append(
                    MultiSignature.ed25519(data: signature),
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            case .substrateEcdsa:
                try scaleEncoder.append(
                    MultiSignature.ecdsa(data: signature),
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            case .ethereumEcdsa:
                guard let signature = EthereumSignature(rawValue: signature) else {
                    throw DAppOperationConfirmInteractorError.invalidRawSignature(
                        data: signature
                    )
                }

                try scaleEncoder.append(
                    signature,
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            }

            return try scaleEncoder.encode()
        }

        signatureOperation.addDependency(codingFactoryOperation)

        signatureOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let rawSignature = try signatureOperation.extractNoCancellableResultData()
                    let response = DAppOperationResponse(signature: rawSignature)

                    self?.presenter?.didReceive(responseResult: .success(response), for: request)
                } catch {
                    self?.presenter?.didReceive(responseResult: .failure(error), for: request)
                }
            }
        }

        operationQueue.addOperations(
            [codingFactoryOperation, signatureOperation],
            waitUntilFinished: false
        )
    }
}

extension DAppSignRawExtrinsicConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
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

            wrapSignatureAndComplete(
                signature,
                account: account,
                request: request
            )
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
