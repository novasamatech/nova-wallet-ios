import Foundation
import NovaCrypto

protocol ParitySignerTxScanViewProtocol: QRScannerViewProtocol {
    func didReceiveExpiration(viewModel: ExpirationTimeViewModel?)
}

protocol ParitySignerTxScanPresenterProtocol: AnyObject {
    func setup()
}

protocol ParitySignerTxScanInteractorInputProtocol: AnyObject {
    func process(scannedSignature: String)
}

protocol ParitySignerTxScanInteractorOutputProtocol: AnyObject {
    func didReceiveSignature(_ signature: IRSignatureProtocol)
    func didReceiveError(_ error: Error)
}

protocol ParitySignerTxScanWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func complete(on view: ParitySignerTxScanViewProtocol?, completionClosure: @escaping () -> Void)
}
