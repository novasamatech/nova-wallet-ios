import Foundation
import Operation_iOS

final class Pdc20DetailsInteractor: NftDetailsInteractor {
    private func provideMedia() {
        guard let imageUrl = nftChainModel.nft.media.flatMap({ URL(string: $0) }) else {
            presenter?.didReceive(media: nil)
            return
        }

        let media = NftImageViewModel(url: imageUrl)
        presenter?.didReceive(media: media)
    }

    private func provideDescription() {
        presenter?.didReceive(description: nil)
    }

    private func provideName() {
        presenter?.didReceive(name: nftChainModel.nft.name)
    }

    private func provideLabel() {
        guard
            let amount = nftChainModel.nft.issuanceMyAmount,
            let totalSupply = nftChainModel.nft.issuanceTotal else {
            presenter?.didReceive(label: .custom(string: nftChainModel.nft.collectionId ?? ""))
            return
        }

        presenter?.didReceive(label: .fungible(amount: amount, totalSupply: totalSupply))
    }

    private func provideIssuer() {
        presenter?.didReceive(issuer: nil)
    }

    private func provideCollection() {
        presenter?.didReceive(collection: nil)
    }

    private func load() {
        provideMedia()
        provideName()
        provideDescription()
        provideLabel()
        provideOwner()
        provideIssuer()
        provideCollection()
        providePrice()
    }
}

extension Pdc20DetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        load()
    }

    func refresh() {
        load()
    }
}
