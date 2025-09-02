import Foundation
import Kingfisher
import Operation_iOS

struct ChainLogoRemoteImageProvider: RemoteImageProvider {
    typealias ImageInfo = ChainLogoImageInfo

    let imageManager: KingfisherManager

    func downloadImageOperation(using imageInfo: ImageInfo) -> BaseOperation<UIImage> {
        let downloader = imageManager.downloader

        return AsyncClosureOperation { resultClosure in
            guard let url = imageInfo.url else {
                resultClosure(.failure(ImageRetrievingError.logoDownloadError))

                return
            }

            let processor = SVGImageProcessor() |> ResizingImageProcessor(referenceSize: imageInfo.scaledSize)

            let options: KingfisherOptionsInfo = [.processor(processor)]

            downloader.downloadImage(with: url, options: options) { result in
                var resultImage: UIImage

                switch result {
                case let .success(imageResult) where imageResult.image.cgImage != nil:
                    resultImage = imageResult.image
                default:
                    resultClosure(.failure(ImageRetrievingError.logoDownloadError))

                    return
                }

                if case .remoteTransparent = imageInfo.type {
                    resultImage = resultImage.redrawWithBackground(
                        color: R.color.colorTextPrimaryOnWhite()!,
                        shape: .circle
                    )
                }

                if let cacheKey = imageInfo.type?.cacheKey {
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
