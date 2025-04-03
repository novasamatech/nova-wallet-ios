import NovaCrypto

protocol ExportMnemonicInteractorInputProtocol: AnyObject {
    func fetchExportData()
}

protocol ExportMnemonicInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: ExportMnemonicData)
    func didReceive(error: Error)
}

protocol ExportMnemonicWireframeProtocol: ExportGenericWireframeProtocol, BackupManualWarningPresentable {
    func openConfirmationForMnemonic(_ mnemonic: IRMnemonicProtocol, from view: ControllerBackedProtocol?)
}
