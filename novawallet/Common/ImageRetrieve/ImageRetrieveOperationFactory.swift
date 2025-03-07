import Foundation
import Kingfisher
import Operation_iOS

struct ImageRetrieveOperationFactory<T> {
    private let imageManager: KingfisherManager
    private let downloadClosure: (T) -> BaseOperation<UIImage>

    init<R: RemoteImageProvider>(
        imageManager: KingfisherManager = KingfisherManager.shared,
        remoteProvider: R
    ) where R.ImageInfo == T {
        self.imageManager = imageManager
        downloadClosure = remoteProvider.downloadImageOperation(using:)
    }
}

extension ImageRetrieveOperationFactory {
    func checkCacheOperation(using cacheKey: String) -> BaseOperation<Bool> {
        let cache = imageManager.cache

        return ClosureOperation {
            let cachedType = cache.imageCachedType(forKey: cacheKey)

            return cachedType.cached
        }
    }

    func downloadImageOperation(using imageInfo: T) -> BaseOperation<UIImage> {
        downloadClosure(imageInfo)
    }

    func retrieveImageOperation(using cacheKey: String) -> BaseOperation<UIImage> {
        let cache = imageManager.cache

        return AsyncClosureOperation { resultClosure in
            cache.retrieveImage(forKey: cacheKey) { result in
                if
                    case let .success(cacheResult) = result,
                    let image = cacheResult.image {
                    resultClosure(.success(image))
                } else {
                    resultClosure(.failure(ImageRetrievingError.logoRetrievingError))
                }
            }
        }
    }
}

extension KingfisherOptionsInfo {
    static let cacheOptions: KingfisherOptionsInfo = [
        .cacheSerializer(RemoteImageSerializer.shared),
        .cacheOriginalImage,
        .diskCacheExpiration(.days(1))
    ]
}

enum ImageRetrievingError: Error {
    case logoDownloadError
    case logoRetrievingError
}
