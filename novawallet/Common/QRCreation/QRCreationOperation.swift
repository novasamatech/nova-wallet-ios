import Foundation
import CoreImage
import Operation_iOS
import Kingfisher
import QRCode

enum QRCreationOperationError: Error {
    case generatorUnavailable
    case generatedImageInvalid
    case bitmapImageCreationFailed
}

enum QRLogoType {
    case remoteColored(URL?)
    case remoteTransparent(URL?)
    case localColored(UIImage)
    case localTransparent(UIImage)

    var url: URL? {
        switch self {
        case let .remoteColored(url), let .remoteTransparent(url):
            return url
        default:
            return nil
        }
    }

    var cacheKey: String? {
        guard let url else { return nil }

        return url.absoluteString + String(describing: self)
    }
}

struct QRLogoInfo {
    let size: CGSize
    let type: QRLogoType?

    var url: URL? {
        type?.url
    }
}

final class QRCreationOperation: BaseOperation<UIImage> {
    let payloadClosure: () throws -> Data
    let qrSize: CGSize
    let logoInfo: QRLogoInfo?

    init(
        payload: Data,
        qrSize: CGSize,
        logoInfo: QRLogoInfo? = nil
    ) {
        payloadClosure = { payload }
        self.qrSize = qrSize
        self.logoInfo = logoInfo

        super.init()
    }

    init(
        qrSize: CGSize,
        logoInfo: QRLogoInfo? = nil,
        payloadClosure: @escaping () throws -> Data
    ) {
        self.qrSize = qrSize
        self.logoInfo = logoInfo
        self.payloadClosure = payloadClosure
    }

    override func performAsync(_ callback: @escaping (Result<UIImage, Error>) -> Void) throws {
        let data = try payloadClosure()
        let qrDoc = QRCode.Document(data: data)
        qrDoc.design.backgroundColor(UIColor.white.cgColor)
        qrDoc.design.shape.eye = QRCode.EyeShape.Squircle()
        qrDoc.design.shape.onPixels = QRCode.PixelShape.Circle(insetFraction: 0.2)
        qrDoc.design.style.onPixels = QRCode.FillStyle.Solid(UIColor.black.cgColor)
        qrDoc.design.shape.offPixels = nil
        qrDoc.design.style.offPixels = nil

        let scale = UIScreen.main.scale

        let scaledSize = CGSize(
            width: qrSize.width * scale,
            height: qrSize.height * scale
        )

        let qrCreateImageClosure: () throws -> Void = { [weak self] in
            guard let self else { return }

            guard let cgImage = qrDoc.cgImage(scaledSize) else {
                throw BarcodeCreationError.bitmapImageCreationFailed
            }

            callback(.success(UIImage(cgImage: cgImage)))
        }

        guard let logoInfo else {
            try qrCreateImageClosure()
            return
        }

        switch logoInfo.type {
        case let .localColored(image):
            qrDoc.logoTemplate = QRCode.LogoTemplate.CircleCenter(
                image: image.cgImage!,
                inset: 0
            )

            try qrCreateImageClosure()
        case let .localTransparent(image):
            qrDoc.logoTemplate = QRCode.LogoTemplate.CircleCenter(
                image: image.cgImage!,
                inset: 20
            )

            try qrCreateImageClosure()
        default:
            try downloadImage(
                using: logoInfo,
                scale: scale
            ) { logoImage in
                let inset: CGFloat = switch logoInfo.type {
                case .remoteTransparent: 20
                default: 0
                }

                qrDoc.logoTemplate = QRCode.LogoTemplate.CircleCenter(
                    image: logoImage,
                    inset: inset
                )

                try qrCreateImageClosure()
            }
        }
    }

    private func downloadImage(
        using logoInfo: QRLogoInfo,
        scale: CGFloat,
        completion: @escaping (CGImage) throws -> Void
    ) throws {
        let scaledSize = CGSize(
            width: logoInfo.size.width * scale,
            height: logoInfo.size.height * scale
        )

        let defaultImage = UIImage.background(from: .white, size: scaledSize)!

        guard let url = logoInfo.url else {
            try completion(defaultImage.cgImage!)

            return
        }

        let options: KingfisherOptionsInfo = [
            .processor(ResizingImageProcessor(referenceSize: scaledSize)),
            .processor(SVGImageProcessor())
        ]

        KingfisherManager.shared.downloader.downloadImage(with: url, options: options) { result in
            var resultImage: UIImage

            switch result {
            case let .success(imageResult) where imageResult.image.cgImage != nil:
                resultImage = imageResult.image
            default:
                resultImage = defaultImage
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

            try? completion(resultImage.cgImage!)
        }
    }
}

extension CGSize {
    static let qrLogoSize: CGSize = .init(width: 80, height: 80)
}
