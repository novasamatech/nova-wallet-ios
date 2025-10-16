import Foundation
import UIKit
import CoreImage
import Operation_iOS

enum QRCreationOperationError: Error {
    case generatorUnavailable
    case generatedImageInvalid
    case bitmapImageCreationFailed
}

final class QRCreationOperation: BaseOperation<UIImage> {
    let payloadClosure: () throws -> Data
    let qrSize: CGSize

    init(payload: Data, qrSize: CGSize) {
        payloadClosure = { payload }
        self.qrSize = qrSize

        super.init()
    }

    init(qrSize: CGSize, payloadClosure: @escaping () throws -> Data) {
        self.qrSize = qrSize
        self.payloadClosure = payloadClosure
    }

    override func performAsync(_ callback: @escaping (Result<UIImage, Error>) -> Void) throws {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw QRCreationOperationError.generatorUnavailable
        }

        let payload = try payloadClosure()

        filter.setValue(payload, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let qrImage = filter.outputImage else {
            throw QRCreationOperationError.generatedImageInvalid
        }

        let transformedImage: CIImage

        if qrImage.extent.size.width * qrImage.extent.height > 0.0 {
            let transform = CGAffineTransform(
                scaleX: qrSize.width / qrImage.extent.width,
                y: qrSize.height / qrImage.extent.height
            )
            transformedImage = qrImage.transformed(by: transform)
        } else {
            transformedImage = qrImage
        }

        let context = CIContext()

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            throw QRCreationOperationError.bitmapImageCreationFailed
        }

        callback(.success(UIImage(cgImage: cgImage)))
    }
}
