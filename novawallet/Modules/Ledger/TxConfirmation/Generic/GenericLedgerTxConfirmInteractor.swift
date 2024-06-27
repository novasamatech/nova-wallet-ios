import Foundation
import Operation_iOS
import SoraKeystore
import SubstrateSdk

final class GenericLedgerTxConfirmInteractor: BaseLedgerTxConfirmInteractor {
    let chain: ChainModel
    let extrinsicParams: LedgerTxConfirmationParams
    let ledgerApplication: GenericLedgerSubstrateApplicationProtocol
    let proofOperationFactory: ExtrinsicProofOperationFactoryProtocol
    let chainConnection: JSONRPCEngine

    init(
        signingData: Data,
        metaId: String,
        chain: ChainModel,
        extrinsicParams: LedgerTxConfirmationParams,
        ledgerConnection: LedgerConnectionManagerProtocol,
        ledgerApplication: GenericLedgerSubstrateApplicationProtocol,
        chainConnection: JSONRPCEngine,
        proofOperationFactory: ExtrinsicProofOperationFactoryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        signatureVerifier: SignatureVerificationWrapperProtocol,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue,
        mortalityPeriodMilliseconds: TimeInterval
    ) {
        self.chain = chain
        self.extrinsicParams = extrinsicParams
        self.ledgerApplication = ledgerApplication
        self.chainConnection = chainConnection
        self.proofOperationFactory = proofOperationFactory

        super.init(
            signingData: signingData,
            metaId: metaId,
            chainId: chain.chainId,
            ledgerConnection: ledgerConnection,
            walletRepository: walletRepository,
            signatureVerifier: signatureVerifier,
            keystore: keystore,
            operationQueue: operationQueue,
            mortalityPeriodMilliseconds: mortalityPeriodMilliseconds
        )
    }

    private func createDerivationPathOperation(
        dependingOn walletOperation: BaseOperation<MetaAccountModel?>,
        keystore: KeystoreProtocol
    ) -> BaseOperation<Data> {
        ClosureOperation {
            guard let wallet = try walletOperation.extractNoCancellableResultData() else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let keystoreTag: String = KeystoreTagV2.substrateDerivationTagForMetaId(
                wallet.metaId,
                accountId: wallet.substrateAccountId!
            )

            return try keystore.fetchKey(for: keystoreTag)
        }
    }

    private func createExtrinsicProofWrapper(
        from params: LedgerTxConfirmationParams
    ) -> CompoundOperationWrapper<Data> {
        let signatureParamsOperation = ClosureOperation<ExtrinsicSignatureParams> {
            let builder = params.extrinsicMemo.restoreBuilder()
            let encoder = params.codingFactory.createEncoder()

            return try builder.buildExtrinsicSignatureParams(
                encodingBy: encoder,
                metadata: params.codingFactory.metadata
            )
        }

        let proofWrapper = proofOperationFactory.createExtrinsicProofWrapper(
            for: chain,
            connection: chainConnection,
            signatureParamsClosure: {
                try signatureParamsOperation.extractNoCancellableResultData()
            }
        )

        proofWrapper.addDependency(operations: [signatureParamsOperation])

        return proofWrapper.insertingHead(operations: [signatureParamsOperation])
    }

    private func createChanAccountOperation(
        dependingOn walletOperation: BaseOperation<MetaAccountModel?>,
        chain: ChainModel
    ) -> BaseOperation<ChainAccountModel> {
        ClosureOperation {
            guard let wallet = try walletOperation.extractNoCancellableResultData() else {
                throw ChainAccountFetchingError.accountNotExists
            }

            if
                let accountId = wallet.substrateAccountId,
                let publicKey = wallet.substratePublicKey,
                let cryptoType = wallet.substrateCryptoType {
                return ChainAccountModel(
                    chainId: chain.chainId,
                    accountId: accountId,
                    publicKey: publicKey,
                    cryptoType: cryptoType,
                    proxy: nil
                )
            } else if let chainAccount = wallet.chainAccounts.first(where: { $0.chainId == chain.chainId }) {
                return chainAccount
            } else {
                throw ChainAccountFetchingError.accountNotExists
            }
        }
    }

    private func createSignatureFetchWrapper(
        dependingOn paramsOperation: BaseOperation<GenericLedgerSubstrateSigningParams>,
        ledgerApplication: GenericLedgerSubstrateApplicationProtocol,
        signingData: Data,
        deviceId: UUID
    ) -> CompoundOperationWrapper<Data> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let params = try paramsOperation.extractNoCancellableResultData()

            return ledgerApplication.getSignWrapper(
                for: signingData,
                deviceId: deviceId,
                params: params
            )
        }
    }

    // MARK: Overriden

    override func performOperation(using deviceId: UUID) {
        let walletOperation = walletRepository.fetchOperation(by: metaId, options: RepositoryFetchOptions())

        let derivationPathOperation = createDerivationPathOperation(
            dependingOn: walletOperation,
            keystore: keystore
        )

        derivationPathOperation.addDependency(walletOperation)

        let proofWrapper = createExtrinsicProofWrapper(from: extrinsicParams)

        let signatureParamsOperation = ClosureOperation<GenericLedgerSubstrateSigningParams> {
            let derivationPath = try derivationPathOperation.extractNoCancellableResultData()
            let proof = try proofWrapper.targetOperation.extractNoCancellableResultData()

            return GenericLedgerSubstrateSigningParams(
                extrinsicProof: proof,
                derivationPath: derivationPath
            )
        }

        signatureParamsOperation.addDependency(derivationPathOperation)
        signatureParamsOperation.addDependency(proofWrapper.targetOperation)

        let signatureFetchWrapper = createSignatureFetchWrapper(
            dependingOn: signatureParamsOperation,
            ledgerApplication: ledgerApplication,
            signingData: signingData,
            deviceId: deviceId
        )

        signatureFetchWrapper.addDependency(operations: [signatureParamsOperation])

        let chainAccountOperation = createChanAccountOperation(
            dependingOn: walletOperation,
            chain: chain
        )

        chainAccountOperation.addDependency(walletOperation)

        let signatureCheckOperation = createSignatureCheckOperation(
            dependingOn: chainAccountOperation,
            signatureFetchOperation: signatureFetchWrapper.targetOperation,
            signingData: signingData,
            signatureVerifier: signatureVerifier
        )

        signatureCheckOperation.addDependency(chainAccountOperation)
        signatureCheckOperation.addDependency(signatureFetchWrapper.targetOperation)

        let proofOperations = [walletOperation, derivationPathOperation] + proofWrapper.allOperations
        let signatureOperations = [signatureParamsOperation] + signatureFetchWrapper.allOperations +
            [chainAccountOperation]

        let totalWrapper = CompoundOperationWrapper(
            targetOperation: signatureCheckOperation,
            dependencies: proofOperations + signatureOperations
        )

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(signature):
                self?.presenter?.didReceiveSigning(result: .success(signature), for: deviceId)
            case let .failure(error):
                self?.presenter?.didReceiveSigning(result: .failure(error), for: deviceId)
            }
        }
    }
}
