import Foundation
import Kingfisher
import Operation_iOS

enum QRCodeFactoryError: Error {
    case logoDownloadError
    case logoRetrievingError
}

protocol QRCodeWithLogoFactoryProtocol {
    func createQRCode(
        with payload: Data,
        logoInfo: QRLogoInfo?,
        qrSize: CGSize,
        completion: @escaping (Result<QRCodeWithLogoFactory.QRCreationResult, Error>) -> Void
    )
}

final class QRCodeWithLogoFactory {
    enum QRCreationResult: Equatable {
        case full(UIImage)
        case noLogo(UIImage)

        var image: UIImage {
            switch self {
            case let .full(image), let .noLogo(image):
                return image
            }
        }
    }

    let imageManager: KingfisherManager
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        imageManager: KingfisherManager = KingfisherManager.shared,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.imageManager = imageManager
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: QRCodeFactoryProtocol

extension QRCodeWithLogoFactory: QRCodeWithLogoFactoryProtocol {
    func createQRCode(
        with payload: Data,
        logoInfo: QRLogoInfo?,
        qrSize: CGSize,
        completion: @escaping (Result<QRCreationResult, Error>) -> Void
    ) {
        let wrapper = createQRWrapper(
            with: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )

        novawallet.execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: completion
        )
    }
}

// MARK: Private

private extension QRCodeWithLogoFactory {
    struct QRWrapperResult {
        let wrapper: CompoundOperationWrapper<QRCreationResult>
        let remoteLogo: Bool
    }

    func checkCacheOperation(
        in cache: ImageCache,
        using logoInfo: QRLogoInfo?
    ) -> ClosureOperation<Bool> {
        ClosureOperation {
            guard
                let logoInfo,
                let cacheKey = logoInfo.type?.cacheKey
            else {
                return false
            }

            let cachedType = cache.imageCachedType(forKey: cacheKey)

            return cachedType.cached
        }
    }

    func createQRWrapper(
        with payload: Data,
        logoInfo: QRLogoInfo?,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<QRCreationResult> {
        let cache = imageManager.cache

        let checkCacheOperation = checkCacheOperation(in: cache, using: logoInfo)

        var remoteLogo = false

        let wrapper: CompoundOperationWrapper<QRCreationResult> = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self, let logoInfo else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            let cached = try checkCacheOperation.extractNoCancellableResultData()
            let usesCache: Bool = logoInfo.type?.cacheKey != nil

            return if !cached, usesCache {
                createDownloadLogoQRWrapper(
                    payload: payload,
                    downloader: imageManager.downloader,
                    logoInfo: logoInfo,
                    qrSize: qrSize
                )
            } else if let cacheKey = logoInfo.type?.cacheKey {
                createCachedLogoQRWrapper(
                    using: cache,
                    cacheKey: cacheKey,
                    payload: payload,
                    logoInfo: logoInfo,
                    qrSize: qrSize
                )
            } else if let image = logoInfo.type?.image {
                createQRResultWrapper(
                    using: .createWithResult(image),
                    payload: payload,
                    logoInfo: logoInfo,
                    qrSize: qrSize
                )
            } else {
                createQRResultWrapper(
                    using: nil,
                    payload: payload,
                    logoInfo: logoInfo,
                    qrSize: qrSize
                )
            }
        }

        wrapper.addDependency(operations: [checkCacheOperation])

        return wrapper.insertingHead(operations: [checkCacheOperation])
    }

    func createDownloadLogoQRWrapper(
        payload: Data,
        downloader: ImageDownloader,
        logoInfo: QRLogoInfo,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<QRCreationResult> {
        let logoOperation = downloadImageOperation(
            using: logoInfo,
            downloader: downloader
        )

        return createQRResultWrapper(
            using: logoOperation,
            payload: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )
    }

    func createCachedLogoQRWrapper(
        using cache: ImageCache,
        cacheKey: String,
        payload: Data,
        logoInfo: QRLogoInfo,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<QRCreationResult> {
        let logoOperation = retrieveImageOperation(
            using: cache,
            cacheKey: cacheKey
        )

        return createQRResultWrapper(
            using: logoOperation,
            payload: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )
    }

    func createQRResultWrapper(
        using logoOperation: BaseOperation<UIImage>?,
        payload: Data,
        logoInfo: QRLogoInfo,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<QRCreationResult> {
        var qrImageWrapper: CompoundOperationWrapper<UIImage>
        qrImageWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            var updatedLogoInfo: QRLogoInfo? = logoInfo

            if let logoOperation {
                do {
                    let logoImage = try logoOperation.extractNoCancellableResultData()
                    updatedLogoInfo = logoInfo.byChangingToLocal(logoImage)
                } catch {
                    logger.error(error.localizedDescription)
                }
            }

            let qrCodeOperation = QRWithLogoCreationOperation(
                payload: payload,
                qrSize: qrSize,
                logoInfo: updatedLogoInfo
            )

            return CompoundOperationWrapper(targetOperation: qrCodeOperation)
        }

        if let logoOperation {
            qrImageWrapper.addDependency(operations: [logoOperation])
            qrImageWrapper = qrImageWrapper.insertingHead(operations: [logoOperation])
        }

        let resultMappingWrapper: CompoundOperationWrapper<QRCreationResult>
        resultMappingWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let qrImage = try qrImageWrapper.targetOperation.extractNoCancellableResultData()

            let result: QRCreationResult = if logoInfo.type != nil {
                .full(qrImage)
            } else {
                .noLogo(qrImage)
            }

            return .createWithResult(result)
        }

        resultMappingWrapper.addDependency(wrapper: qrImageWrapper)

        return resultMappingWrapper.insertingHead(operations: qrImageWrapper.allOperations)
    }

    func downloadImageOperation(
        using logoInfo: QRLogoInfo,
        downloader: ImageDownloader
    ) -> AsyncClosureOperation<UIImage> {
        AsyncClosureOperation { resultClosure in
            let scale = UIScreen.main.scale

            let scaledSize = CGSize(
                width: logoInfo.size.width * scale,
                height: logoInfo.size.height * scale
            )

            guard let url = logoInfo.url else {
                resultClosure(.failure(QRCodeFactoryError.logoDownloadError))

                return
            }

            let options: KingfisherOptionsInfo = [
                .processor(ResizingImageProcessor(referenceSize: scaledSize)),
                .processor(SVGImageProcessor())
            ]

            downloader.downloadImage(with: url, options: options) { result in
                var resultImage: UIImage

                switch result {
                case let .success(imageResult) where imageResult.image.cgImage != nil:
                    resultImage = imageResult.image
                default:
                    resultClosure(.failure(QRCodeFactoryError.logoDownloadError))

                    return
                }

                let sizeBeforeProcessing = resultImage.size

                if case .remoteTransparent = logoInfo.type {
                    resultImage = resultImage.redrawWithBackground(
                        color: R.color.colorTextPrimaryOnWhite()!,
                        shape: .circle
                    )
                }

                if let cacheKey = logoInfo.type?.cacheKey {
                    KingfisherManager.shared.cache.store(
                        resultImage,
                        forKey: cacheKey,
                        options: KingfisherParsedOptionsInfo(nil)
                    )
                }

                resultClosure(.success(resultImage))
            }
        }
    }

    func retrieveImageOperation(
        using cache: ImageCache,
        cacheKey: String
    ) -> AsyncClosureOperation<UIImage> {
        AsyncClosureOperation { resultClosure in
            cache.retrieveImage(forKey: cacheKey) { [weak self] result in
                guard let self else { return }

                if
                    case let .success(cacheResult) = result,
                    let image = cacheResult.image {
                    resultClosure(.success(image))
                } else {
                    resultClosure(.failure(QRCodeFactoryError.logoRetrievingError))
                }
            }
        }
    }
}
