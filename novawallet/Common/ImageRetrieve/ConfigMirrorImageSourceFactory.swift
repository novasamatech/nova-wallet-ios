import Foundation
import Kingfisher

struct ConfigMirrorImageSource {
    let source: Source
    let options: KingfisherOptionsInfo
}

/// Makes Kingfisher load images the config mirror serves from the mirror first and from the original url
/// when the mirror fails. The cache key stays the original url so that both attempts share one cache entry
/// and the images cached before the mirror existed remain valid.
struct ConfigMirrorImageSourceFactory {
    private let urlResolver: ConfigMirrorURLResolverProtocol

    init(urlResolver: ConfigMirrorURLResolverProtocol = ConfigMirrorURLResolver.shared) {
        self.urlResolver = urlResolver
    }

    func createSource(for url: URL) -> ConfigMirrorImageSource {
        guard let mirrorURL = urlResolver.mirrorURL(for: url) else {
            return ConfigMirrorImageSource(source: url.convertToSource(), options: [])
        }

        let cacheKey = url.absoluteString
        let mirrorResource = Kingfisher.ImageResource(downloadURL: mirrorURL, cacheKey: cacheKey)
        let originalResource = Kingfisher.ImageResource(downloadURL: url, cacheKey: cacheKey)

        return ConfigMirrorImageSource(
            source: .network(mirrorResource),
            options: [.alternativeSources([.network(originalResource)])]
        )
    }

    func downloadImage(
        with url: URL,
        using downloader: ImageDownloader,
        options: KingfisherOptionsInfo,
        completionHandler: @escaping (Result<ImageLoadingResult, KingfisherError>) -> Void
    ) {
        guard let mirrorURL = urlResolver.mirrorURL(for: url) else {
            downloader.downloadImage(with: url, options: options, completionHandler: completionHandler)
            return
        }

        downloader.downloadImage(with: mirrorURL, options: options) { result in
            if case .success = result {
                completionHandler(result)
            } else {
                downloader.downloadImage(with: url, options: options, completionHandler: completionHandler)
            }
        }
    }
}
