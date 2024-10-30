import Operation_iOS

protocol QRCreationOperationFactoryProtocol {
    func createOperation(
        payload: Data,
        logoInfo: QRLogoInfo?,
        qrSize: CGSize
    ) -> QRCreationOperation
}

final class QRCreationOperationFactory: QRCreationOperationFactoryProtocol {
    func createOperation(
        payload: Data,
        logoInfo: QRLogoInfo?,
        qrSize: CGSize
    ) -> QRCreationOperation {
        QRCreationOperation(
            payload: payload,
            qrSize: qrSize,
            logoInfo: logoInfo
        )
    }
}
