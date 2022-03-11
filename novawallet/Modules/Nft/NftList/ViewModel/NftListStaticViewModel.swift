import Foundation

final class NftListStaticViewModel {
    let name: String
    let label: String
    let media: NftMediaViewModelProtocol?

    init(
        name: String,
        label: String,
        media: NftMediaViewModelProtocol?
    ) {
        self.name = name
        self.label = label
        self.media = media
    }
}

extension NftListStaticViewModel: NftListMetadataViewModelProtocol {
    func load(on view: NftListItemViewProtocol, completion: ((Error?) -> Void)?) {
        view.setName(name)
        view.setLabel(label)
        view.setMedia(media)

        completion?(nil)
    }

    func cancel(on _: NftListItemViewProtocol) {}
}
