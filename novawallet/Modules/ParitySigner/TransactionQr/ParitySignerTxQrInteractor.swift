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

    private func createMetadataProofWrapper(
        from params: ParitySignerSigningMode.Extrinsic
    ) -> CompoundOperationWrapper<Data> {
        do {
            let chain = try chainRegistry.getChainOrError(for: chainId)
            let chainConnection = try chainRegistry.getConnectionOrError(for: chainId)

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
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    private func createTransactionWithExtrinsicWrapper(
        for account: ChainAccountResponse,
        params: ParitySignerSigningMode.Extrinsic
    ) -> CompoundOperationWrapper<Data> {
        guard params.codingFactory.supportsMetadataHash() else {
            return messageOperationFactory.createMetadataBasedTransaction(
                for: signingData,
                accountId: account.accountId,
                cryptoType: account.cryptoType,
                genesisHash: chainId
            )
        }

        let metadataProofWrapper = createMetadataProofWrapper(from: params)

        let transactionWrapper = messageOperationFactory.createProofBasedTransaction(
            for: signingData,
            metadataProofClosure: {
                try metadataProofWrapper.targetOperation.extractNoCancellableResultData()
            },
            accountId: account.accountId,
            cryptoType: account.cryptoType,
            genesisHash: chainId
        )

        transactionWrapper.addDependency(wrapper: metadataProofWrapper)

        return transactionWrapper.insertingHead(operations: metadataProofWrapper.allOperations)
    }

    private func createTransactionWrapper(for account: ChainAccountResponse) -> CompoundOperationWrapper<Data> {
        switch params.mode {
        case let .extrinsic(extrinsicParams):
            createTransactionWithExtrinsicWrapper(
                for: account,
                params: extrinsicParams
            )
        case .rawBytes:
            messageOperationFactory.createMessage(
                for: signingData,
                accountId: account.accountId,
                cryptoType: account.cryptoType,
                genesisHash: chainId
            )
        }
    }

    private func provideTransactionCode(
        for size: CGSize,
        account: ChainAccountResponse
    ) {
        let transactionWrapper = createTransactionWrapper(for: account)

        let qrPayloadWrapper = multipartQrOperationFactory.createFromPayloadClosure {
            try transactionWrapper.targetOperation.extractNoCancellableResultData()
        }

        qrPayloadWrapper.addDependency(wrapper: transactionWrapper)

        let qrCreationOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let paylods = try qrPayloadWrapper.targetOperation.extractNoCancellableResultData()

            return paylods.map { payload in
                let operation = QRCreationOperation(payload: payload, qrSize: size)
                return CompoundOperationWrapper(targetOperation: operation)
            }
        }.longrunOperation()

        qrCreationOperation.addDependency(qrPayloadWrapper.targetOperation)

        let expirationTime = mortalityPeriodMilliseconds.seconds

        qrCreationOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let qrCodes = try qrCreationOperation.extractNoCancellableResultData()
                    let txCode = TransactionDisplayCode(images: qrCodes, expirationTime: expirationTime)
                    self?.presenter?.didReceive(transactionCode: txCode)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        let operations = transactionWrapper.allOperations + qrPayloadWrapper.allOperations + [qrCreationOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func subscribeChains(for chainId: ChainModel.Id, qrSize: CGSize) {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            if let chain = changes.mergeToDict([String: ChainModel]())[chainId] {
                self?.provideDisplayWalletAndQr(for: chain, qrSize: qrSize)
            }
        }
    }

    private func provideDisplayWalletAndQr(for chain: ChainModel, qrSize: CGSize) {
        let walletFetchOperation = walletRepository.fetchOperation(by: metaId, options: RepositoryFetchOptions())

        walletFetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let wallet = try walletFetchOperation.extractNoCancellableResultData()

                    guard
                        let accountResponse = wallet?.fetchMetaChainAccount(
                            for: chain.accountRequest()
                        ) else {
                        self?.presenter?.didReceive(error: ChainAccountFetchingError.accountNotExists)
                        return
                    }

                    let walletDisplayAddress = try accountResponse.toWalletDisplayAddress()

                    let model = ChainWalletDisplayAddress(
                        chain: chain,
                        walletDisplayAddress: walletDisplayAddress
                    )

                    self?.presenter?.didReceive(chainWallet: model)

                    self?.provideTransactionCode(for: qrSize, account: accountResponse.chainAccount)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(walletFetchOperation)
    }
}

extension ParitySignerTxQrInteractor: ParitySignerTxQrInteractorInputProtocol {
    func setup(qrSize: CGSize) {
        subscribeChains(for: chainId, qrSize: qrSize)
    }
}
