import Foundation

protocol PolkadotVaultScanWireframeProtocol: AnyObject {
    func completeScan(
        on view: ControllerBackedProtocol?,
        accountScan: PolkadotVaultAccountScan,
        type: ParitySignerType
    )
}

protocol PolkadotVaultScanInteractorInputProtocol: AnyObject {
    func process(accountScan: PolkadotVaultAccountScan)
}

protocol PolkadotVaultScanInteractorOutputProtocol: AnyObject {
    func didReceiveValidation(result: Result<PolkadotVaultAccountScan, Error>)
}
