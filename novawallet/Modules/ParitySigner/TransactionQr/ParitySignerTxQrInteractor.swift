import UIKit
import RobinHood

final class ParitySignerTxQrInteractor {
    weak var presenter: ParitySignerTxQrInteractorOutputProtocol?

    let signingData: Data
    let metaId: String
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let messageOperationFactory: ParitySignerMessageOperationFactoryProtocol
    let multipartQrOperationFactory: MultipartQrOperationFactoryProtocol
    let mortalityPeriodMilliseconds: TimeInterval
    let operationQueue: OperationQueue

    init(
        signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        messageOperationFactory: ParitySignerMessageOperationFactoryProtocol,
        multipartQrOperationFactory: MultipartQrOperationFactoryProtocol,
        mortalityPeriodMilliseconds: TimeInterval,
        operationQueue: OperationQueue
    ) {
        self.signingData = signingData
        self.metaId = metaId
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.walletRepository = walletRepository
        self.messageOperationFactory = messageOperationFactory
        self.multipartQrOperationFactory = multipartQrOperationFactory
        self.mortalityPeriodMilliseconds = mortalityPeriodMilliseconds
        self.operationQueue = operationQueue
    }

    private func provideTransactionCode(for size: CGSize, account: ChainAccountResponse) {
        let messageWrapper = messageOperationFactory.createTransaction(
            for: signingData,
            accountId: account.accountId,
            cryptoType: account.cryptoType,
            genesisHash: chainId
        )

        let qrPayloadWrapper = multipartQrOperationFactory.createFromPayloadClosure {
            try messageWrapper.targetOperation.extractNoCancellableResultData()
        }

        qrPayloadWrapper.addDependency(wrapper: messageWrapper)

        let qrCreationOperation = QRCreationOperation(qrSize: size) {
            if let payload = try qrPayloadWrapper.targetOperation.extractNoCancellableResultData().first {
                return payload
            } else {
                throw CommonError.dataCorruption
            }
        }

        qrCreationOperation.addDependency(qrPayloadWrapper.targetOperation)

        let expirationTime = mortalityPeriodMilliseconds.seconds

        qrCreationOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let qrCode = try qrCreationOperation.extractNoCancellableResultData()
                    let txCode = TransactionDisplayCode(image: qrCode, expirationTime: expirationTime)
                    self?.presenter?.didReceive(transactionCode: txCode)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        let operations = messageWrapper.allOperations + qrPayloadWrapper.allOperations + [qrCreationOperation]

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
