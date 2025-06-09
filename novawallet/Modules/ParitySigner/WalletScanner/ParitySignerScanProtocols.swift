import Foundation

protocol ParitySignerScanWireframeProtocol: AnyObject {
    func completeScan(
        on view: ControllerBackedProtocol?,
        walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType
    )
}

protocol ParitySignerScanInteractorInputProtocol: AnyObject {
    func process(walletScan: ParitySignerWalletScan)
}

protocol ParitySignerScanInteractorOutputProtocol: AnyObject {
    func didReceiveValidation(result: Result<ParitySignerWalletFormat, Error>)
}
