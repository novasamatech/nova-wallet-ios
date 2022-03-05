import UIKit
import RobinHood
import BigInt

enum NftDetailsInteractorError: Error {
    case unsupportedMetadata(_ data: Data)
}

class NftDetailsInteractor {
    weak var presenter: NftDetailsInteractorOutputProtocol!

    let nftChainModel: NftChainModel
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue

    var chain: ChainModel { nftChainModel.chainAsset.chain }

    init(
        nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.nftChainModel = nftChainModel
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
    }

    func fetchDisplayAddress(
        for accountId: AccountId,
        chain: ChainModel,
        completion: @escaping ((Result<DisplayAddress, Error>) -> Void)
    ) {
        let allAccountsOperation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<DisplayAddress> {
            let metaAccounts = try allAccountsOperation.extractNoCancellableResultData()

            let optionAccount = metaAccounts.first { metaAccount in
                metaAccount.substrateAccountId == accountId ||
                    metaAccount.ethereumAddress == accountId ||
                    metaAccount.chainAccounts.contains { chainAccount in
                        chainAccount.accountId == accountId && chainAccount.chainId == chain.chainId
                    }
            }

            let address = try accountId.toAddress(using: chain.chainFormat)

            if let account = optionAccount {
                return DisplayAddress(address: address, username: account.name)
            } else {
                return DisplayAddress(address: address, username: "")
            }
        }

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let displayAddress = try mapOperation.extractNoCancellableResultData()
                    completion(.success(displayAddress))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        mapOperation.addDependency(allAccountsOperation)

        operationQueue.addOperations([allAccountsOperation, mapOperation], waitUntilFinished: false)
    }

    func provideOwner() {
        fetchDisplayAddress(
            for: nftChainModel.nft.ownerId,
            chain: nftChainModel.chainAsset.chain
        ) { [weak self] result in
            switch result {
            case let .success(owner):
                self?.presenter.didReceive(owner: owner)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }

    func providePrice() {
        if let priceString = nftChainModel.nft.price, let price = BigUInt(priceString) {
            presenter.didReceive(price: price, tokenPriceData: nftChainModel.price)
        } else {
            presenter.didReceive(price: nil, tokenPriceData: nftChainModel.price)
        }
    }
}
