import Foundation
import RobinHood

final class RMRKV2DetailsInteractor: NftDetailsInteractor {
    let operationFactory: RMRKV2NftOperationFactoryProtocol

    private(set) var issuerOperation: CancellableCall?
    private(set) var collectionOperation: CancellableCall?

    init(
        nftChainModel: NftChainModel,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationFactory: RMRKV2NftOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory

        super.init(
            nftChainModel: nftChainModel,
            accountRepository: accountRepository,
            nftMetadataService: nftMetadataService,
            operationQueue: operationQueue
        )
    }

    deinit {
        issuerOperation?.cancel()
        collectionOperation?.cancel()
    }

    private func provideInstanceDetails() {
        if let image = nftChainModel.nft.media, let url = URL(string: image) {
            let mediaViewModel = NftImageViewModel(url: url)

            presenter?.didReceive(media: mediaViewModel)

            provideInstanceMetadata(false)
        } else {
            provideInstanceMetadata(true)
        }
    }

    private func provideCollection(from model: RMRKV2Collection) {
        if
            let issuer = model.issuer,
            let issuerId = try? issuer.toAccountId(using: chain.chainFormat) {
            if issuerOperation == nil {
                issuerOperation = fetchDisplayAddress(for: issuerId, chain: chain) { [weak self] result in
                    self?.issuerOperation = nil

                    switch result {
                    case let .success(displayAddress):
                        self?.presenter?.didReceive(issuer: displayAddress)
                    case let .failure(error):
                        self?.presenter?.didReceive(error: error)
                    }
                }
            }
        } else {
            presenter?.didReceive(issuer: nil)
        }

        guard let name = model.symbol else {
            presenter?.didReceive(collection: nil)
            return
        }

        if let metadata = model.metadata {
            if collectionOperation == nil {
                collectionOperation = nftMetadataService.resolveImageUrl(
                    for: metadata,
                    aliases: NftMediaAlias.list,
                    dispatchQueue: .main
                ) { [weak self] result in
                    self?.collectionOperation = nil

                    switch result {
                    case let .success(url):
                        let collection = NftDetailsCollection(name: name, imageUrl: url)
                        self?.presenter?.didReceive(collection: collection)
                    case let .failure(error):
                        self?.presenter?.didReceive(error: error)
                    }
                }
            }
        } else {
            let collection = NftDetailsCollection(name: name, imageUrl: nil)
            presenter?.didReceive(collection: collection)
        }
    }

    private func provideCollection() {
        guard collectionOperation == nil, issuerOperation == nil else {
            return
        }

        guard let collectionId = nftChainModel.nft.collectionId else {
            presenter?.didReceive(collection: nil)
            presenter?.didReceive(issuer: nil)
            return
        }

        let fetchOperation = operationFactory.fetchCollection(for: collectionId)

        collectionOperation = fetchOperation

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.collectionOperation = nil

                do {
                    if let collection = try fetchOperation.extractNoCancellableResultData().first {
                        self?.provideCollection(from: collection)
                    } else {
                        self?.presenter?.didReceive(collection: nil)
                    }
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func provideLabel() {
        if
            let snString = nftChainModel.nft.label,
            let serialNumber = UInt32(snString),
            let totalIssuance = nftChainModel.nft.totalIssuance,
            totalIssuance > 0 {
            let label: NftDetailsLabel = .limited(
                serialNumber: serialNumber,
                totalIssuance: UInt32(bitPattern: totalIssuance)
            )

            presenter?.didReceive(label: label)
        } else {
            presenter?.didReceive(label: .unlimited)
        }
    }

    private func load() {
        provideOwner()
        provideInstanceDetails()
        provideCollection()
        provideLabel()
        providePrice()
    }
}

extension RMRKV2DetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        load()
    }

    func refresh() {
        load()
    }
}
