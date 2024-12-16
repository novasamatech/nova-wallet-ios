import Foundation
import Kingfisher
import Operation_iOS

struct KingfisherIconRetrieveOperationFactory {
    let imageManager: KingfisherManager
    let operationQueue: OperationQueue

    init(
        imageManager: KingfisherManager = KingfisherManager.shared,
        operationQueue: OperationQueue
    ) {
        self.imageManager = imageManager
        self.operationQueue = operationQueue
    }
}

// MARK: IconRetrieveOperationFactoryProtocol

extension KingfisherIconRetrieveOperationFactory: IconRetrieveOperationFactoryProtocol {
    func checkCacheOperation(using cacheKey: String) -> Operation_iOS.ClosureOperation<Bool> {
        let cache = imageManager.cache

        return ClosureOperation {
            let cachedType = cache.imageCachedType(forKey: cacheKey)

            return cachedType.cached
        }
    }

    func downloadImageOperation(using iconInfo: IconInfo) -> Operation_iOS.AsyncClosureOperation<UIImage> {
        let downloader = imageManager.downloader

        return AsyncClosureOperation { resultClosure in
            let scale = UIScreen.main.scale

            let scaledSize = CGSize(
                width: iconInfo.size.width * scale,
                height: iconInfo.size.height * scale
            )

            guard let url = iconInfo.url else {
                resultClosure(.failure(ImageRetrievingError.logoDownloadError))

                return
            }

            let processor = SVGImageProcessor() |> ResizingImageProcessor(referenceSize: scaledSize)

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

                if case .remoteTransparent = iconInfo.type {
                    resultImage = resultImage.redrawWithBackground(
                        color: R.color.colorTextPrimaryOnWhite()!,
                        shape: .circle
                    )
                }

                if let cacheKey = iconInfo.type?.cacheKey {
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

    func retrieveImageOperation(using cacheKey: String) -> Operation_iOS.AsyncClosureOperation<UIImage> {
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
