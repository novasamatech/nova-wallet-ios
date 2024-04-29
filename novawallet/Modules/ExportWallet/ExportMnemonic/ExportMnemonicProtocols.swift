import IrohaCrypto

protocol ExportMnemonicInteractorInputProtocol: AnyObject {
    func fetchExportData()
}

protocol ExportMnemonicInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: ExportMnemonicData)
    func didReceive(error: Error)
}

protocol ExportMnemonicWireframeProtocol: ExportGenericWireframeProtocol {
    func openConfirmationForMnemonic(_ mnemonic: IRMnemonicProtocol, from view: ExportGenericViewProtocol?)
}
