import Foundation
import Kingfisher
import Operation_iOS
import UIKit

struct CommonRemoteImageProvider: RemoteImageProvider {
    typealias ImageInfo = CommonImageInfo

    let imageManager: KingfisherManager
    let imageSourceFactory: ConfigMirrorImageSourceFactory

    init(
        imageManager: KingfisherManager,
        imageSourceFactory: ConfigMirrorImageSourceFactory = ConfigMirrorImageSourceFactory()
    ) {
        self.imageManager = imageManager
        self.imageSourceFactory = imageSourceFactory
    }

    func downloadImageOperation(using imageInfo: ImageInfo) -> BaseOperation<UIImage> {
        let downloader = imageManager.downloader

        return AsyncClosureOperation { resultClosure in
            guard let url = imageInfo.url else {
                resultClosure(.failure(ImageRetrievingError.logoDownloadError))

                return
            }

            let processor = DefaultImageProcessor() |> ResizingImageProcessor(referenceSize: imageInfo.scaledSize)

            let options: KingfisherOptionsInfo = [.processor(processor)]

            imageSourceFactory.downloadImage(with: url, using: downloader, options: options) { result in
                var resultImage: UIImage

                switch result {
                case let .success(imageResult) where imageResult.image.cgImage != nil:
                    resultImage = imageResult.image
                default:
                    resultClosure(.failure(ImageRetrievingError.logoDownloadError))

                    return
                }

                if let cacheKey = imageInfo.cacheKey {
                    let cacheOptions = KingfisherOptionsInfo.cacheOptions

                    imageManager.cache.store(
                        resultImage,
                        forKey: cacheKey,
                        options: KingfisherParsedOptionsInfo(cacheOptions)
                    )
                }

                resultClosure(.success(resultImage))
            }
        }
    }
}
