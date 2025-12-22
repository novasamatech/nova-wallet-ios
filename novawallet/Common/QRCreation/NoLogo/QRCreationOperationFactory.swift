import Foundation
import UIKit
import Operation_iOS

protocol QRCreationOperationFactoryProtocol {
    func createOperation(payload: Data, qrSize: CGSize) -> BaseOperation<UIImage>
}

final class QRCreationOperationFactory: QRCreationOperationFactoryProtocol {
    func createOperation(payload: Data, qrSize: CGSize) -> BaseOperation<UIImage> {
        QRCreationOperation(payload: payload, qrSize: qrSize)
    }
}
