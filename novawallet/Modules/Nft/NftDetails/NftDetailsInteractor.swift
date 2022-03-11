import UIKit
import RobinHood
import BigInt
import SubstrateSdk

enum NftDetailsInteractorError: Error {
    case unsupportedMetadata(_ data: Data)
}

class NftDetailsInteractor {
    weak var presenter: NftDetailsInteractorOutputProtocol?

    let nftChainModel: NftChainModel
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue
    let nftMetadataService: NftFileDownloadServiceProtocol

    var chain: ChainModel { nftChainModel.chainAsset.chain }

    private(set) var ownerOperation: CancellableCall?
    private(set) var instanceOperation: CancellableCall?

    init(
        nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.nftChainModel = nftChainModel
        self.accountRepository = accountRepository
        self.nftMetadataService = nftMetadataService
        self.operationQueue = operationQueue
    }

    deinit {
        ownerOperation?.cancel()
        instanceOperation?.cancel()
    }

    func fetchDisplayAddress(
        for accountId: AccountId,
        chain: ChainModel,
        completion: @escaping ((Result<DisplayAddress, Error>) -> Void)
    ) -> CancellableCall {
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

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [allAccountsOperation])

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        return wrapper
    }

    func provideOwner() {
        guard ownerOperation == nil else {
            return
        }

        ownerOperation = fetchDisplayAddress(
            for: nftChainModel.nft.ownerId,
            chain: nftChainModel.chainAsset.chain
        ) { [weak self] result in
            self?.ownerOperation = nil

            switch result {
            case let .success(owner):
                self?.presenter?.didReceive(owner: owner)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func providePrice() {
        if let priceString = nftChainModel.nft.price, let price = BigUInt(priceString) {
            presenter?.didReceive(price: price, tokenPriceData: nftChainModel.price)
        } else {
            presenter?.didReceive(price: nil, tokenPriceData: nftChainModel.price)
        }
    }

    private func provideInstanceInfo(from json: JSON) {
        let name = json.name?.stringValue
        presenter?.didReceive(name: name)

        let description = json.description?.stringValue
        presenter?.didReceive(description: description)
    }

    func provideInstanceMetadata(_ shouldProvideMedia: Bool = true) {
        if let metadata = nftChainModel.nft.metadata {
            guard let metadataReference = String(data: metadata, encoding: .utf8) else {
                let error = NftDetailsInteractorError.unsupportedMetadata(metadata)
                presenter?.didReceive(error: error)
                return
            }

            if shouldProvideMedia {
                let mediaViewModel = NftMediaViewModel(
                    metadataReference: metadataReference,
                    downloadService: nftMetadataService
                )

                presenter?.didReceive(media: mediaViewModel)
            }

            guard instanceOperation == nil else {
                return
            }

            instanceOperation = nftMetadataService.downloadMetadata(
                for: metadataReference,
                dispatchQueue: .main
            ) { [weak self] result in
                self?.instanceOperation = nil

                switch result {
                case let .success(json):
                    self?.provideInstanceInfo(from: json)
                case let .failure(error):
                    self?.presenter?.didReceive(error: error)
                }
            }

        } else {
            presenter?.didReceive(name: nil)
            presenter?.didReceive(media: nil)
            presenter?.didReceive(description: nil)
        }
    }
}
