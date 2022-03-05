import Foundation

final class RMRKV2DetailsInteractor: NftDetailsInteractor {
    private func provideModelInstance() {
        if
            let mediaString = nftChainModel.nft.media,
            let url = URL(string: mediaString) {
            let mediaViewModel = NftImageViewModel(url: url)
            presenter.didReceive(media: mediaViewModel)

            provideInstanceMetadata(false)
        } else {
            provideInstanceMetadata(true)
        }
    }

    private func provideLabel() {
        presenter.didReceive(label: .unlimited)
    }
}

extension RMRKV2DetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        provideOwner()
        providePrice()
        provideModelInstance()
        provideLabel()
    }
}
