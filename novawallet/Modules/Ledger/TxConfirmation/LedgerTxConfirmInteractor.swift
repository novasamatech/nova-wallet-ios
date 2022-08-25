import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import SubstrateSdk

enum LedgerTxConfirmInteractorError: Error {
    case invalidSignature
}

final class LedgerTxConfirmInteractor: LedgerPerformOperationInteractor {
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
    let ledgerApplication: LedgerApplicationProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let signatureVerifier: SignatureVerificationWrapperProtocol
    let keystore: KeystoreProtocol
    let operationQueue: OperationQueue

    init(
        signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        ledgerConnection: LedgerConnectionManagerProtocol,
        ledgerApplication: LedgerApplicationProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        signatureVerifier: SignatureVerificationWrapperProtocol,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingData = signingData
        self.metaId = metaId
        self.chainId = chainId
        self.ledgerApplication = ledgerApplication
        self.walletRepository = walletRepository
        self.signatureVerifier = signatureVerifier
        self.keystore = keystore
        self.operationQueue = operationQueue

        super.init(ledgerConnection: ledgerConnection)
    }

    private func createChainAccountWrapper(
        metaId: String,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<ChainAccountModel> {
        let walletOperation = walletRepository.fetchOperation(by: metaId, options: RepositoryFetchOptions())

        let mappingOperation = ClosureOperation<ChainAccountModel> {
            let wallet = try walletOperation.extractNoCancellableResultData()

            guard let chainAccount = wallet?.chainAccounts.first(where: { $0.chainId == chainId }) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            return chainAccount
        }

        mappingOperation.addDependency(walletOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [walletOperation])
    }

    private func createDerivationPathOperation(
        dependingOn chainAccountOperation: BaseOperation<ChainAccountModel>,
        keystore: KeystoreProtocol,
        metaId: String,
        chainId _: ChainModel.Id
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let chainAccount = try chainAccountOperation.extractNoCancellableResultData()

            let keystoreTag: String = KeystoreTagV2.derivationTagForMetaId(
                metaId,
                accountId: chainAccount.accountId,
                isEthereumBased: chainAccount.isEthereumBased
            )

            return try keystore.fetchKey(for: keystoreTag)
        }
    }

    private func createSignatureOperation(
        dependingOn chainAccountOperation: BaseOperation<ChainAccountModel>,
        signatureFetchOperation: BaseOperation<Data>,
        signingData: Data,
        signatureVerifier: SignatureVerificationWrapperProtocol
    ) -> BaseOperation<IRSignatureProtocol> {
        ClosureOperation {
            let chainAccount = try chainAccountOperation.extractNoCancellableResultData()
            let rawSignature = try signatureFetchOperation.extractNoCancellableResultData()

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

    override func performOperation(using deviceId: UUID) {
        let chainAccountWrapper = createChainAccountWrapper(metaId: metaId, chainId: chainId)

        let derivationPathOperation = createDerivationPathOperation(
            dependingOn: chainAccountWrapper.targetOperation,
            keystore: keystore,
            metaId: metaId,
            chainId: chainId
        )

        derivationPathOperation.addDependency(chainAccountWrapper.targetOperation)

        let signatureFetchWrapper = ledgerApplication.getSignWrapper(
            for: signingData,
            deviceId: deviceId,
            chainId: chainId
        ) {
            try derivationPathOperation.extractNoCancellableResultData()
        }

        signatureFetchWrapper.addDependency(operations: [derivationPathOperation])

        let signatureOperation = createSignatureOperation(
            dependingOn: chainAccountWrapper.targetOperation,
            signatureFetchOperation: signatureFetchWrapper.targetOperation,
            signingData: signingData,
            signatureVerifier: signatureVerifier
        )

        signatureOperation.addDependency(chainAccountWrapper.targetOperation)
        signatureOperation.addDependency(signatureFetchWrapper.targetOperation)

        signatureOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let signature = try signatureOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceiveSigning(result: .success(signature), for: deviceId)
                } catch {
                    self?.presenter?.didReceiveSigning(result: .failure(error), for: deviceId)
                }
            }
        }

        let operations = chainAccountWrapper.allOperations + [derivationPathOperation] +
            signatureFetchWrapper.allOperations + [signatureOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}
