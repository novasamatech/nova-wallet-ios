import Foundation

protocol PVScanWireframeProtocol: AnyObject {
    func completeScan(
        on view: ControllerBackedProtocol?,
        account: PolkadotVaultAccount,
        type: ParitySignerType
    )
}

protocol PVScanInteractorInputProtocol: AnyObject {
    func process(accountScan: PolkadotVaultAccount)
}

protocol PVScanInteractorOutputProtocol: AnyObject {
    func didReceiveValidation(result: Result<PolkadotVaultAccount, Error>)
}
