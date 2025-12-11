import UIKit
import Operation_iOS
import SubstrateSdk

final class ParitySignerTxQrInteractor {
    weak var presenter: ParitySignerTxQrInteractorOutputProtocol?

    let signingData: Data
    let params: ParitySignerConfirmationParams
    let metaId: String
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let messageOperationFactory: ParitySignerMessageOperationFactoryProtocol
    let multipartQrOperationFactory: MultipartQrOperationFactoryProtocol
    let proofOperationFactory: ExtrinsicProofOperationFactoryProtocol
    let mortalityPeriodMilliseconds: TimeInterval
    let operationQueue: OperationQueue

    private var derivedAccount: ChainAccountResponse?
    private var cancellableStore = CancellableCallStore()

    init(
        signingData: Data,
        params: ParitySignerConfirmationParams,
        metaId: String,
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        messageOperationFactory: ParitySignerMessageOperationFactoryProtocol,
        proofOperationFactory: ExtrinsicProofOperationFactoryProtocol,
        multipartQrOperationFactory: MultipartQrOperationFactoryProtocol,
        mortalityPeriodMilliseconds: TimeInterval,
        operationQueue: OperationQueue
    ) {
        self.signingData = signingData
        self.params = params
        self.metaId = metaId
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.walletRepository = walletRepository
        self.messageOperationFactory = messageOperationFactory
        self.proofOperationFactory = proofOperationFactory
        self.multipartQrOperationFactory = multipartQrOperationFactory
        self.mortalityPeriodMilliseconds = mortalityPeriodMilliseconds
        self.operationQueue = operationQueue
    }

    deinit {
        cancellableStore.cancel()
    }
}

// Transaction QR generation logic
private extension ParitySignerTxQrInteractor {
    func provideTransactionCode(
        for account: ChainAccountResponse,
        qrFormat: ParitySignerQRFormat,
        qrSize: CGSize
    ) {
        cancellableStore.cancel()

        let transactionWrapper = createTransactionWrapper(for: account, qrFormat: qrFormat, qrSize: qrSize)

        executeCancellable(
            wrapper: transactionWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didReceive(transactionCode: model)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func createTransactionWrapper(
        for account: ChainAccountResponse,
        qrFormat: ParitySignerQRFormat,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<TransactionDisplayCode> {
        do {
            switch qrFormat {
            case .rawBytes:
                try params.mode.ensureRawBytes()

                return createTransactionWithRawBytesWrapper(for: account, qrSize: qrSize)
            case .extrinsicWithoutProof, .extrinsicWithProof:
                let params = try params.mode.ensureExtrinsic()

                let includesProof = qrFormat == .extrinsicWithProof

                return createTransactionWithExtrinsicWrapper(
                    for: account,
                    extrinsicParams: params,
                    qrSize: qrSize,
                    includesProof: includesProof
                )
            }
        } catch {
            return .createWithError(error)
        }
    }

    func createTransactionWithExtrinsicWrapper(
        for account: ChainAccountResponse,
        extrinsicParams: ParitySignerSigningMode.Extrinsic,
        qrSize: CGSize,
        includesProof: Bool
    ) -> CompoundOperationWrapper<TransactionDisplayCode> {
        let transactionWrapper: CompoundOperationWrapper<Data>

        if includesProof {
            let metadataProofWrapper = createMetadataProofWrapper(from: extrinsicParams)

            let messageWrapper = messageOperationFactory.createProofBasedTransaction(
                for: signingData,
                metadataProofClosure: {
                    try metadataProofWrapper.targetOperation.extractNoCancellableResultData()
                },
                accountId: account.accountId,
                cryptoType: account.cryptoType,
                genesisHash: chainId
            )

            messageWrapper.addDependency(wrapper: metadataProofWrapper)

            transactionWrapper = messageWrapper.insertingHead(operations: metadataProofWrapper.allOperations)
        } else {
            transactionWrapper = messageOperationFactory.createMetadataBasedTransaction(
                for: signingData,
                accountId: account.accountId,
                cryptoType: account.cryptoType,
                genesisHash: chainId
            )
        }

        let qrCodesWrapper = createQrImagesWrapper(dependingOn: transactionWrapper.targetOperation, qrSize: qrSize)

        qrCodesWrapper.addDependency(wrapper: transactionWrapper)

        let mergeOperation = ClosureOperation<TransactionDisplayCode> {
            let qrCodes = try qrCodesWrapper.targetOperation.extractNoCancellableResultData()

            return TransactionDisplayCode(images: qrCodes)
        }

        mergeOperation.addDependency(qrCodesWrapper.targetOperation)

        return qrCodesWrapper
            .insertingHead(operations: transactionWrapper.allOperations)
            .insertingTail(operation: mergeOperation)
    }

    func createMetadataProofWrapper(
        from params: ParitySignerSigningMode.Extrinsic
    ) -> CompoundOperationWrapper<Data> {
        do {
            let chain = try chainRegistry.getChainOrError(for: chainId)
            let chainConnection = try chainRegistry.getConnectionOrError(for: chainId)

            let signatureParamsOperation = ClosureOperation<ExtrinsicSignatureParams> {
                let builder = params.extrinsicMemo.restoreBuilder()

                return try builder.buildExtrinsicSignatureParams(
                    encodingFactory: params.codingFactory,
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
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createTransactionWithRawBytesWrapper(
        for account: ChainAccountResponse,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<TransactionDisplayCode> {
        let transactionWrapper = messageOperationFactory.createMessage(
            for: signingData,
            accountId: account.accountId,
            cryptoType: account.cryptoType,
            genesisHash: chainId
        )

        let qrCodesWrapper = createQrImagesWrapper(dependingOn: transactionWrapper.targetOperation, qrSize: qrSize)

        qrCodesWrapper.addDependency(wrapper: transactionWrapper)

        let mergeOperation = ClosureOperation<TransactionDisplayCode> {
            let qrCodes = try qrCodesWrapper.targetOperation.extractNoCancellableResultData()

            return TransactionDisplayCode(images: qrCodes)
        }

        mergeOperation.addDependency(qrCodesWrapper.targetOperation)

        return qrCodesWrapper
            .insertingHead(operations: transactionWrapper.allOperations)
            .insertingTail(operation: mergeOperation)
    }

    func createQrImagesWrapper(
        dependingOn dataOperation: BaseOperation<Data>,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<[UIImage]> {
        let qrPayloadWrapper = multipartQrOperationFactory.createFromPayloadClosure {
            try dataOperation.extractNoCancellableResultData()
        }

        let qrCreationOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let paylods = try qrPayloadWrapper.targetOperation.extractNoCancellableResultData()

            return paylods.map { payload in
                let operation = QRCreationOperation(payload: payload, qrSize: qrSize)
                return CompoundOperationWrapper(targetOperation: operation)
            }
        }.longrunOperation()

        qrCreationOperation.addDependency(qrPayloadWrapper.targetOperation)

        return qrPayloadWrapper.insertingTail(operation: qrCreationOperation)
    }
}

// Setup logic
private extension ParitySignerTxQrInteractor {
    func setupDisplayWallet(for chain: ChainModel) {
        let walletFetchOperation = walletRepository.fetchOperation(by: metaId, options: RepositoryFetchOptions())

        execute(
            operation: walletFetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            do {
                let wallet = try result.get()

                guard
                    let accountResponse = wallet?.fetchMetaChainAccount(
                        for: chain.accountRequest()
                    ) else {
                    self?.presenter?.didReceive(error: ChainAccountFetchingError.accountNotExists)
                    return
                }

                self?.completeSetup(for: chain, account: accountResponse)
            } catch {
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func getPreferredFormats() -> ParitySignerPreferredQRFormats {
        switch params.mode {
        case .rawBytes:
            return [.rawBytes]
        case let .extrinsic(extrinsic):
            if params.type == .vault, extrinsic.canIncludeProof {
                return [.extrinsicWithProof, .extrinsicWithoutProof]
            } else {
                return [.extrinsicWithoutProof]
            }
        }
    }

    func completeSetup(for chain: ChainModel, account: MetaChainAccountResponse) {
        do {
            let walletDisplayAddress = try account.toWalletDisplayAddress()

            let chainWalletModel = ChainWalletDisplayAddress(
                chain: chain,
                walletDisplayAddress: walletDisplayAddress
            )

            derivedAccount = account.chainAccount

            let txExpirationTime: TimeInterval? = switch params.mode {
            case .extrinsic:
                mortalityPeriodMilliseconds
            case .rawBytes:
                nil
            }

            let model = ParitySignerTxQrSetupModel(
                chainWallet: chainWalletModel,
                preferredFormats: getPreferredFormats(),
                txExpirationTime: txExpirationTime?.seconds
            )

            presenter?.didCompleteSetup(model: model)
        } catch {
            presenter?.didReceive(error: error)
        }
    }
}

extension ParitySignerTxQrInteractor: ParitySignerTxQrInteractorInputProtocol {
    func setup() {
        do {
            let chain = try chainRegistry.getChainOrError(for: chainId)
            setupDisplayWallet(for: chain)
        } catch {
            presenter?.didReceive(error: error)
        }
    }

    func generateQr(with format: ParitySignerQRFormat, qrSize: CGSize) {
        guard let derivedAccount else {
            return
        }

        provideTransactionCode(
            for: derivedAccount,
            qrFormat: format,
            qrSize: qrSize
        )
    }
}
