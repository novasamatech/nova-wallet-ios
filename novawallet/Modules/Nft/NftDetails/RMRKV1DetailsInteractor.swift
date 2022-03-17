import Foundation
import RobinHood
import SubstrateSdk

final class RMRKV1DetailsInteractor: NftDetailsInteractor {
    let operationFactory: RMRKV1NftOperationFactoryProtocol

    private(set) var issuerOperation: CancellableCall?
    private(set) var collectionOperation: CancellableCall?

    init(
        nftChainModel: NftChainModel,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationFactory: RMRKV1NftOperationFactoryProtocol,
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

    private func provideCollection(from model: RMRKV1Collection) {
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

        guard let name = model.name else {
            presenter?.didReceive(collection: nil)
            return
        }

        if let metadata = model.metadata {
            if collectionOperation == nil {
                collectionOperation = nftMetadataService.resolveImageUrl(
                    for: metadata,
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
            let totalIssuance = nftChainModel.nft.totalIssuance {
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
        provideInstanceMetadata()
        provideCollection()
        provideLabel()
        providePrice()
    }
}

extension RMRKV1DetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        load()
    }

    func refresh() {
        load()
    }
}
