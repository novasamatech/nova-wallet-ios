import Foundation
import CoreImage
import Operation_iOS
import Kingfisher
import QRCode

final class QRWithLogoCreationOperation: BaseOperation<UIImage> {
    let payloadClosure: () throws -> Data
    let qrSize: CGSize
    let logoInfo: IconInfo?

    init(
        payload: Data,
        qrSize: CGSize,
        logoInfo: IconInfo? = nil
    ) {
        payloadClosure = { payload }
        self.qrSize = qrSize
        self.logoInfo = logoInfo

        super.init()
    }

    init(
        qrSize: CGSize,
        logoInfo: IconInfo? = nil,
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

        let qrCreateImageClosure: () throws -> Void = { [weak self] in
            guard let self else { return }

            let scale = UIScreen.main.scale

            let scaledSize = CGSize(
                width: qrSize.width * scale,
                height: qrSize.height * scale
            )

            guard let cgImage = qrDoc.cgImage(scaledSize) else {
                throw BarcodeCreationError.bitmapImageCreationFailed
            }

            callback(.success(UIImage(cgImage: cgImage)))
        }

        switch logoInfo?.type {
        case let .localColored(image):
            qrDoc.logoTemplate = QRCode.LogoTemplate.CircleCenter(
                image: image.cgImage!,
                inset: 0
            )
        case let .localTransparent(image):
            qrDoc.logoTemplate = QRCode.LogoTemplate.CircleCenter(
                image: image.cgImage!,
                inset: 20
            )
        default:
            break
        }

        try qrCreateImageClosure()
    }
}

extension CGSize {
    static let qrLogoSize: CGSize = .init(width: 80, height: 80)
}
