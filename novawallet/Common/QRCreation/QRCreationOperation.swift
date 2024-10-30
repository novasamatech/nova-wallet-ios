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

final class QRCreationOperation: BaseOperation<UIImage> {
    let payloadClosure: () throws -> Data
    let qrSize: CGSize
    let logoSize: CGSize?
    let logoURL: URL?

    init(
        payload: Data,
        qrSize: CGSize,
        logoURL: URL?,
        logoSize: CGSize? = nil
    ) {
        payloadClosure = { payload }
        self.qrSize = qrSize
        self.logoSize = logoSize
        self.logoURL = logoURL

        super.init()
    }

    init(
        qrSize: CGSize,
        logoURL: URL?,
        logoSize: CGSize?,
        payloadClosure: @escaping () throws -> Data
    ) {
        self.qrSize = qrSize
        self.logoURL = logoURL
        self.logoSize = logoSize
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

        guard let logoSize else {
            try qrCreateImageClosure()
            return
        }

        try retrieveImage(
            of: logoSize,
            scale: scale,
            using: logoURL
        ) { logoImage in
            qrDoc.logoTemplate = QRCode.LogoTemplate.CircleCenter(image: logoImage)

            try qrCreateImageClosure()
        }
    }

    private func retrieveImage(
        of size: CGSize,
        scale: CGFloat,
        using url: URL?,
        completion: @escaping (CGImage) throws -> Void
    ) throws {
        let defaultTokenImage = R.image.iconDefaultToken()!

        let scaledSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        guard let url else {
            try completion(
                defaultTokenImage.kf.resize(to: scaledSize).cgImage!
            )

            return
        }

        let options: KingfisherOptionsInfo = [.processor(SVGImageProcessor())]

        KingfisherManager.shared.downloader.downloadImage(with: url, options: options) { result in
            let resultImage: UIImage

            switch result {
            case let .success(imageResult) where imageResult.image.cgImage != nil:
                resultImage = imageResult.image
            default:
                resultImage = defaultTokenImage
            }

            let resizedImage = resultImage.kf.resize(to: scaledSize)

            try? completion(resizedImage.cgImage!)
        }
    }
}
