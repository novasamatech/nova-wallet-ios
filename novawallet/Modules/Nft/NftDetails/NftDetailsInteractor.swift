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

    let ownerCancellable = CancellableCallStore()
    private(set) var instanceOperation: CancellableCall?
    let issuerCancellable = CancellableCallStore()

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
        ownerCancellable.cancel()
        instanceOperation?.cancel()
        issuerCancellable.cancel()
    }

    func createDisplayAddressWrapper(
        for accountId: AccountId,
        chain: ChainModel
    ) -> CompoundOperationWrapper<DisplayAddress> {
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

        mapOperation.addDependency(allAccountsOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [allAccountsOperation])
    }

    func fetchDisplayAddress(
        for accountId: AccountId,
        chain: ChainModel,
        completion: @escaping ((Result<DisplayAddress, Error>) -> Void)
    ) -> CancellableCall {
        let wrapper = createDisplayAddressWrapper(for: accountId, chain: chain)

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let displayAddress = try wrapper.targetOperation.extractNoCancellableResultData()
                    completion(.success(displayAddress))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        return wrapper
    }

    func provideIssuer(from address: String?) {
        issuerCancellable.cancel()

        guard let address = address, let accountId = try? address.toAccountId(using: chain.chainFormat) else {
            presenter?.didReceive(issuer: nil)
            return
        }

        let wrapper = createDisplayAddressWrapper(for: accountId, chain: chain)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: issuerCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(displayAddress):
                self?.presenter?.didReceive(issuer: displayAddress)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func provideOwner() {
        ownerCancellable.cancel()

        let wrapper = createDisplayAddressWrapper(
            for: nftChainModel.nft.ownerId,
            chain: chain
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: ownerCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(owner):
                self?.presenter?.didReceive(owner: owner)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func providePrice() {
        guard let priceValue = nftChainModel.nft.price.flatMap({ BigUInt($0) }) else {
            presenter?.didReceive(price: nil, tokenPriceData: nftChainModel.price)
            return
        }

        let priceUnits = nftChainModel.nft.priceUnits.flatMap { BigUInt($0) }

        let model = NftDetailsPrice(value: priceValue, units: priceUnits)

        presenter?.didReceive(price: model, tokenPriceData: nftChainModel.price)
    }

    private func provideInstanceInfo(from json: JSON) {
        let name = json.name?.stringValue ?? nftChainModel.nft.name ?? nftChainModel.nft.instanceId
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
                    aliases: NftMediaAlias.details,
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
            let name = nftChainModel.nft.name ?? nftChainModel.nft.instanceId

            presenter?.didReceive(name: name)

            if shouldProvideMedia {
                presenter?.didReceive(media: nil)
            }

            presenter?.didReceive(description: nil)
        }
    }
}
