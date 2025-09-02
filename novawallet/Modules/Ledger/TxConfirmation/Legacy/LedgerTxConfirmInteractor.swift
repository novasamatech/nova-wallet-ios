import UIKit
import Operation_iOS
import Keystore_iOS
import NovaCrypto
import SubstrateSdk

final class LedgerTxConfirmInteractor: BaseLedgerTxConfirmInteractor {
    let ledgerApplication: LedgerApplicationProtocol

    init(
        signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        ledgerConnection: LedgerConnectionManagerProtocol,
        ledgerApplication: LedgerApplicationProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        signatureVerifier: SignatureVerificationWrapperProtocol,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue,
        mortalityPeriodMilliseconds: TimeInterval
    ) {
        self.ledgerApplication = ledgerApplication

        super.init(
            signingData: signingData,
            metaId: metaId,
            chainId: chainId,
            ledgerConnection: ledgerConnection,
            walletRepository: walletRepository,
            signatureVerifier: signatureVerifier,
            keystore: keystore,
            operationQueue: operationQueue,
            mortalityPeriodMilliseconds: mortalityPeriodMilliseconds
        )
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
        metaId: String
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

    // MARK: Overriden

    override func performOperation(using deviceId: UUID) {
        let chainAccountWrapper = createChainAccountWrapper(metaId: metaId, chainId: chainId)

        let derivationPathOperation = createDerivationPathOperation(
            dependingOn: chainAccountWrapper.targetOperation,
            keystore: keystore,
            metaId: metaId
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

        let signatureOperation = createSignatureCheckOperation(
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
