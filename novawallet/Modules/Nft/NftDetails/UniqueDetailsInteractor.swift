import Foundation
import Operation_iOS
import SubstrateSdk

final class UniqueDetailsInteractor: NftDetailsInteractor {
    let operationFactory: UniqueNftOperationFactoryProtocol

    init(
        nftChainModel: NftChainModel,
        nftMetadataService: NftFileDownloadServiceProtocol, // nftMetadataService пока остается, т.к. базовый класс его требует
        operationFactory: UniqueNftOperationFactoryProtocol,
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

    private func provideMedia(from imageUrlString: String?) {
        let mediaViewModel: NftMediaViewModelProtocol?

        if let urlString = imageUrlString, !urlString.isEmpty, let directUrl = URL(string: urlString) {
            mediaViewModel = NftImageViewModel(url: directUrl)
        } else {
            mediaViewModel = nil
        }

        presenter?.didReceive(media: mediaViewModel)
    }

    private func provideDefaultDetails() {
        presenter?.didReceive(name: nftChainModel.nft.name ?? nftChainModel.nft.instanceId)
        provideMedia(from: nftChainModel.nft.media)

        presenter?.didReceive(description: nftChainModel.nft.metadata.flatMap { String(data: $0, encoding: .utf8) })
    }

    private func provideUniqueLabel() {
        presenter?.didReceive(label: .unlimited)
    }

    private func loadDetails() {
        provideOwner()
        provideDefaultDetails()
        provideUniqueLabel()
        providePrice()
    }
}

extension UniqueDetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        loadDetails()
    }

    func refresh() {
        loadDetails()
    }
}
