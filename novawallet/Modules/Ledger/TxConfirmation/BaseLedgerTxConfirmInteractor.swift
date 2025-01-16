import Foundation
import Operation_iOS
import Keystore_iOS
import SubstrateSdk
import IrohaCrypto

class BaseLedgerTxConfirmInteractor: LedgerPerformOperationInteractor {
    var presenter: LedgerTxConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? LedgerTxConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let signingData: Data
    let metaId: String
    let chainId: ChainModel.Id
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let signatureVerifier: SignatureVerificationWrapperProtocol
    let keystore: KeystoreProtocol
    let operationQueue: OperationQueue
    let mortalityPeriodMilliseconds: TimeInterval

    init(
        signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        ledgerConnection: LedgerConnectionManagerProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        signatureVerifier: SignatureVerificationWrapperProtocol,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue,
        mortalityPeriodMilliseconds: TimeInterval
    ) {
        self.signingData = signingData
        self.metaId = metaId
        self.chainId = chainId
        self.walletRepository = walletRepository
        self.signatureVerifier = signatureVerifier
        self.keystore = keystore
        self.operationQueue = operationQueue
        self.mortalityPeriodMilliseconds = mortalityPeriodMilliseconds

        super.init(ledgerConnection: ledgerConnection)
    }

    private func provideExpirationTimeInterval() {
        let expirationTime = mortalityPeriodMilliseconds.seconds

        presenter?.didReceiveTransactionExpiration(timeInterval: expirationTime)
    }

    func createSignatureCheckOperation(
        dependingOn chainAccountOperation: BaseOperation<ChainAccountModel>,
        signatureFetchOperation: BaseOperation<Data>,
        signingData: Data,
        signatureVerifier: SignatureVerificationWrapperProtocol
    ) -> BaseOperation<IRSignatureProtocol> {
        ClosureOperation {
            let chainAccount = try chainAccountOperation.extractNoCancellableResultData()

            // drop signature type
            let rawSignature = try signatureFetchOperation.extractNoCancellableResultData().dropFirst()

            let originalData: Data

            if !chainAccount.isEthereumBased {
                originalData = try ExtrinsicSignatureConverter.convertExtrinsicPayloadToRegular(signingData)
            } else {
                originalData = signingData
            }

            guard
                let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType),
                let signature = try signatureVerifier.verify(
                    rawSignature: rawSignature,
                    originalData: originalData,
                    rawPublicKey: chainAccount.publicKey,
                    cryptoType: cryptoType
                ) else {
                throw LedgerTxConfirmInteractorError.invalidSignature
            }

            return signature
        }
    }

    // MARK: Overriden

    override func setup() {
        super.setup()

        provideExpirationTimeInterval()
    }
}

extension BaseLedgerTxConfirmInteractor: LedgerTxConfirmInteractorInputProtocol {
    func cancelTransactionRequest(for deviceId: UUID) {
        ledgerConnection.cancelRequest(for: deviceId)
    }
}
