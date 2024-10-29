import Operation_iOS

protocol QRCreationOperationFactoryProtocol {
    func createOperation(
        payload: Data,
        qrSize: CGSize
    ) -> BaseOperation<UIImage>
}

final class QRCreationOperationFactory: QRCreationOperationFactoryProtocol {
    private let logoSize: CGSize

    init(logoSize: CGSize = .init(width: 64, height: 64)) {
        self.logoSize = logoSize
    }

    func createOperation(
        payload: Data,
        qrSize: CGSize
    ) -> BaseOperation<UIImage> {
        QRCreationOperation(
            payload: payload,
            qrSize: qrSize,
            logoSize: logoSize
        )
    }
}
