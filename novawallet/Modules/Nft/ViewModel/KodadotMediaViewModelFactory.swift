import Foundation

enum KodadotMediaViewModelFactory {
    static func createMediaViewModel(
        from mediaString: String?,
        using downloadService: NftFileDownloadServiceProtocol
    ) -> NftMediaViewModelProtocol? {
        guard let mediaString else {
            return nil
        }

        if let imageUrl = downloadService.imageUrl(from: mediaString) {
            return NftImageViewModel(url: imageUrl)
        }

        if
            !mediaString.isEmpty,
            let imageUrl = URL(string: mediaString) {
            return NftImageViewModel(url: imageUrl)
        }

        return nil
    }
}
