import UIKit
import RobinHood

final class ParitySignerTxQrInteractor {
    weak var presenter: ParitySignerTxQrInteractorOutputProtocol?

    let signingData: Data
    let metaId: String
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let mortalityPeriodMilliseconds: TimeInterval
    let operationQueue: OperationQueue

    init(
        signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        mortalityPeriodMilliseconds: TimeInterval,
        operationQueue: OperationQueue
    ) {
        self.signingData = signingData
        self.metaId = metaId
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.walletRepository = walletRepository
        self.mortalityPeriodMilliseconds = mortalityPeriodMilliseconds
        self.operationQueue = operationQueue
    }

    private func provideTransactionCode(for size: CGSize, expirationTime: TimeInterval) {
        let operation = QRCreationOperation(payload: signingData, qrSize: size)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let qrCode = try operation.extractNoCancellableResultData()
                    let txCode = TransactionDisplayCode(image: qrCode, expirationTime: expirationTime)
                    self?.presenter?.didReceive(transactionCode: txCode)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func subscribeChainsAndProvideDisplayWallet(for chainId: ChainModel.Id) {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            if let chain = changes.mergeToDict([String: ChainModel]())[chainId] {
                self?.provideDisplayWallet(for: chain)
            }
        }
    }

    private func provideDisplayWallet(for chain: ChainModel) {
        let walletFetchOperation = walletRepository.fetchOperation(by: metaId, options: RepositoryFetchOptions())

        walletFetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let wallet = try walletFetchOperation.extractNoCancellableResultData()

                    guard
                        let walletDisplayAddress = try wallet?.fetchMetaChainAccount(
                            for: chain.accountRequest()
                        )?.toWalletDisplayAddress() else {
                        self?.presenter?.didReceive(error: ChainAccountFetchingError.accountNotExists)
                        return
                    }

                    let model = ChainWalletDisplayAddress(
                        chain: chain,
                        walletDisplayAddress: walletDisplayAddress
                    )

                    self?.presenter?.didReceive(chainWallet: model)
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
        provideTransactionCode(for: qrSize, expirationTime: mortalityPeriodMilliseconds.seconds)
        subscribeChainsAndProvideDisplayWallet(for: chainId)
    }
}
