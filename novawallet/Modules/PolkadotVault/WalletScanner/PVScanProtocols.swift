import Foundation

protocol PVScanWireframeProtocol: AnyObject {
    func completeScan(
        on view: ControllerBackedProtocol?,
        account: PolkadotVaultAccount,
        type: ParitySignerType
    )
}
