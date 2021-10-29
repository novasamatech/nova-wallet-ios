import UIKit
import RobinHood
import SoraKeystore

final class AccountManagementInteractor {
    weak var presenter: AccountManagementInteractorOutputProtocol?

    let chainRepository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue
    let wallet: MetaAccountModel
    let logger: LoggerProtocol

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        wallet: MetaAccountModel,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.wallet = wallet
        self.logger = logger
    }

    private func fetchChains() throws -> [ChainModel] {
        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }
}

extension AccountManagementInteractor: AccountManagementInteractorInputProtocol {
    func setup() {
        do {
            let chains = try fetchChains()

            let chainsById: [ChainModel.Id: ChainModel] = chains.reduce(into: [:]) { result, chain in
                result[chain.chainId] = chain
            }

            presenter?.didReceiveChains(.success(chainsById))
            presenter?.didReceiveWallet(wallet)
        } catch {
            presenter?.didReceiveChains(.failure(error))
        }
    }
}
