import Foundation
import Operation_iOS

final class KodaDotDetailsInteractor: NftDetailsInteractor {
    let operationFactory: KodaDotNftOperationFactoryProtocol

    let metadataCancellable = CancellableCallStore()
    let collectionCancellable = CancellableCallStore()

    init(
        nftChainModel: NftChainModel,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationFactory: KodaDotNftOperationFactoryProtocol,
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
        metadataCancellable.cancel()
        collectionCancellable.cancel()
    }

    private func provideMedia(from reference: String?) {
        let mediaViewModel = KodadotMediaViewModelFactory.createMediaViewModel(
            from: reference,
            using: nftMetadataService
        )

        presenter?.didReceive(media: mediaViewModel)
    }

    private func provideDefaultInstanceDetails() {
        let nftModel = nftChainModel.nft
        let name = nftModel.name ?? nftModel.instanceId
        presenter?.didReceive(name: name)
        provideMedia(from: nftModel.media)
        presenter?.didReceive(description: nil)
    }

    private func provideInstanceDetails(from metadataResponse: KodaDotNftMetadataResponse) {
        guard let metadata = metadataResponse.metadataEntityById else {
            provideDefaultInstanceDetails()
            return
        }

        presenter?.didReceive(name: metadata.name)
        provideMedia(from: metadata.image)
        presenter?.didReceive(description: metadata.description)
    }

    private func provideInstanceDetails() {
        metadataCancellable.cancel()

        guard let metadataId = nftChainModel.nft.metadata.flatMap({ String(data: $0, encoding: .utf8) }) else {
            provideDefaultInstanceDetails()
            return
        }

        let metadataWrapper = operationFactory.fetchMetadata(for: metadataId)

        executeCancellable(
            wrapper: metadataWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: metadataCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(reponse):
                self?.provideInstanceDetails(from: reponse)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    private func provideDefaultCollectionDetails() {
        presenter?.didReceive(issuer: nil)
        presenter?.didReceive(collection: nil)
    }

    private func provideCollectionDetails(from response: KodaDotNftCollectionResponse) {
        guard let collection = response.collectionEntityById else {
            provideDefaultCollectionDetails()
            return
        }

        provideIssuer(from: collection.issuer)

        let optImageUrl = collection.image.flatMap { nftMetadataService.imageUrl(from: $0) }

        let collectionModel = NftDetailsCollection(name: collection.name ?? "", imageUrl: optImageUrl)
        presenter?.didReceive(collection: collectionModel)
    }

    private func provideCollection() {
        collectionCancellable.cancel()

        guard let collectionId = nftChainModel.nft.collectionId else {
            provideDefaultCollectionDetails()
            return
        }

        let collectionWrapper = operationFactory.fetchCollection(for: collectionId)

        executeCancellable(
            wrapper: collectionWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: collectionCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(response):
                self?.provideCollectionDetails(from: response)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    private func provideLabel() {
        if
            let snString = nftChainModel.nft.label,
            let serialNumber = UInt32(snString),
            let totalIssuance = nftChainModel.nft.issuanceTotal,
            totalIssuance > 0 {
            let label: NftDetailsLabel = .limited(
                serialNumber: serialNumber,
                totalIssuance: totalIssuance
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

extension KodaDotDetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        load()
    }

    func refresh() {
        load()
    }
}
