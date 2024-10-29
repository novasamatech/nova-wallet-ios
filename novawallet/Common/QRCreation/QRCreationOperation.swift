import Foundation
import CoreImage
import Operation_iOS
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

    init(
        payload: Data,
        qrSize: CGSize,
        logoSize: CGSize? = nil
    ) {
        payloadClosure = { payload }
        self.qrSize = qrSize
        self.logoSize = logoSize

        super.init()
    }

    init(
        qrSize: CGSize,
        logoSize: CGSize?,
        payloadClosure: @escaping () throws -> Data
    ) {
        self.qrSize = qrSize
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

        if let logoSize {
            let scaledSize = CGSize(
                width: logoSize.width * UIScreen.main.scale,
                height: logoSize.height * UIScreen.main.scale
            )

            guard let image = UIImage.background(from: .white, size: scaledSize)?.cgImage else {
                return
            }

            qrDoc.logoTemplate = QRCode.LogoTemplate.CircleCenter(image: image)
        }

        let scaledSize = CGSize(
            width: qrSize.width * UIScreen.main.scale,
            height: qrSize.height * UIScreen.main.scale
        )

        guard let cgImage = qrDoc.cgImage(scaledSize) else {
            throw BarcodeCreationError.bitmapImageCreationFailed
        }

        callback(.success(UIImage(cgImage: cgImage)))
    }
}
