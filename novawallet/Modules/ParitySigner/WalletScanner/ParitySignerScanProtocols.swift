import Foundation

protocol ParitySignerScanWireframeProtocol: AnyObject {
    func completeScan(on view: ControllerBackedProtocol?, addressScan: ParitySignerAddressScan)
}

protocol ParitySignerScanInteractorInputProtocol: AnyObject {
    func process(addressScan: ParitySignerAddressScan)
}

protocol ParitySignerScanInteractorOutputProtocol: AnyObject {
    func didReceiveValidation(result: Result<ParitySignerAddressScan, Error>)
}
