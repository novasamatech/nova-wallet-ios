import Foundation

protocol ExportViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: ExportViewLayout.Model)
    func updateNavbar(with viewModel: DisplayWalletViewModel)
    func updateNavbar(with text: String)
    func showSecret(
        _ secret: String,
        for chainName: String
    )
}

protocol ExportPresenterProtocol: AnyObject {
    func setup()
}

protocol ExportInteractorInputProtocol: AnyObject {
    func requestExportOptions(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    )

    func requestSeedForSubstrate(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    )

    func requestKeyForEthereum(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    )
}

protocol ExportInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: ExportData)
    func didReceive(seed: Data, for chainName: String)
    func didReceive(_ error: Error)
}

protocol ExportWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showExportRestoreJSON(from view: ExportViewProtocol?)
}
