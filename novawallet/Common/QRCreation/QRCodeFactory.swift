import Foundation
import Kingfisher
import Operation_iOS

protocol QRCodeFactoryProtocol {
    func createQRCode(
        with payload: Data,
        logoInfo: QRLogoInfo?,
        qrSize: CGSize,
        completion: @escaping (QRCodeFactory.Result) -> Void
    )
}

final class QRCodeFactory {
    enum Result: Equatable {
        case full(UIImage)
        case noLogo(UIImage)

        var image: UIImage {
            switch self {
            case let .full(image), let .noLogo(image):
                return image
            }
        }
    }

    let operationFactory: QRCreationOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        operationFactory: QRCreationOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}

// MARK: QRCodeFactoryProtocol

extension QRCodeFactory: QRCodeFactoryProtocol {
    func createQRCode(
        with payload: Data,
        logoInfo: QRLogoInfo?,
        qrSize: CGSize,
        completion: @escaping (Result) -> Void
    ) {
        let cache = KingfisherManager.shared.cache

        var cached: Bool = {
            guard let logoInfo, let cacheKey = logoInfo.type?.cacheKey else { return false }

            let cachedType = cache.imageCachedType(forKey: cacheKey)

            return cachedType.cached
        }()

        var usesCache: Bool { logoInfo?.type?.cacheKey != nil }

        guard let logoInfo else {
            return
        }

        if !cached, usesCache {
            createQRCodes(
                using: payload,
                logoInfo: logoInfo,
                qrSize: qrSize,
                completion: completion
            )
        } else if let cacheKey = logoInfo.type?.cacheKey {
            createQRCode(
                using: cache,
                cacheKey: cacheKey,
                payload: payload,
                logoInfo: logoInfo,
                qrSize: qrSize,
                completion: completion
            )
        } else {
            createQRCode(
                using: payload,
                logoInfo: logoInfo,
                qrSize: qrSize,
                completion: completion
            )
        }
    }
}

// MARK: Private

private extension QRCodeFactory {
    func createQRCode(
        using payload: Data,
        logoInfo: QRLogoInfo,
        qrSize: CGSize,
        completion: @escaping (Result) -> Void
    ) {
        let operation = operationFactory.createOperation(
            payload: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )

        execute(
            [(operation: operation, withLogo: true)],
            completion: completion
        )
    }

    func createQRCode(
        using cache: ImageCache,
        cacheKey: String,
        payload: Data,
        logoInfo: QRLogoInfo,
        qrSize: CGSize,
        completion: @escaping (Result) -> Void
    ) {
        cache.retrieveImage(forKey: cacheKey) { [weak self] result in
            guard let self else { return }

            var updatedLogoInfo: QRLogoInfo? = logoInfo

            if case let .success(cacheResult) = result, let image = cacheResult.image {
                updatedLogoInfo = QRLogoInfo(
                    size: logoInfo.size,
                    type: .local(image)
                )
            }

            let operation = operationFactory.createOperation(
                payload: payload,
                logoInfo: updatedLogoInfo,
                qrSize: qrSize
            )

            execute(
                [(operation: operation, withLogo: true)],
                completion: completion
            )
        }
    }

    func createQRCodes(
        using payload: Data,
        logoInfo: QRLogoInfo,
        qrSize: CGSize,
        completion: @escaping (Result) -> Void
    ) {
        let noLogoQROperation = operationFactory.createOperation(
            payload: payload,
            logoInfo: QRLogoInfo(size: logoInfo.size, type: nil),
            qrSize: qrSize
        )

        let embeddedLogoQROperation = operationFactory.createOperation(
            payload: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )

        let operations = [
            (operation: noLogoQROperation, withLogo: false),
            (operation: embeddedLogoQROperation, withLogo: true)
        ]

        execute(operations, completion: completion)
    }

    func execute(
        _ operations: [(operation: QRCreationOperation, withLogo: Bool)],
        completion: @escaping (Result) -> Void
    ) {
        operations.forEach { operation in
            novawallet.execute(
                operation: operation.operation,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { result in
                switch result {
                case let .success(qrCodeImage):
                    let qrCreationResult: Result = operation.withLogo
                        ? .full(qrCodeImage)
                        : .noLogo(qrCodeImage)

                    completion(qrCreationResult)
                case let .failure(error):
                    print(error)
                }
            }
        }
    }
}
