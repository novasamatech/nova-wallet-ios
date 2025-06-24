import Foundation

protocol ParitySignerScanWireframeProtocol: AnyObject {
    func completeScan(
        on view: ControllerBackedProtocol?,
        walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    )
}

protocol ParitySignerScanInteractorInputProtocol: AnyObject {
    func process(walletUpdate: PolkadotVaultWalletUpdate)
}

protocol ParitySignerScanInteractorOutputProtocol: AnyObject {
    func didReceiveValidation(result: Result<PolkadotVaultWalletUpdate, Error>)
}
