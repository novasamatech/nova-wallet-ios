import Foundation

protocol AdvancedExportViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: AdvancedExportViewLayout.Model)
    func showSecret(
        _ secret: String,
        for chainName: String
    )
}

protocol AdvancedExportPresenterProtocol: AnyObject {
    func setup()
}

protocol AdvancedExportInteractorInputProtocol: AnyObject {
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

protocol AdvancedExportInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: AdvancedExportData)
    func didReceive(seed: Data, for chainName: String)
    func didReceive(_ error: Error)
}

protocol AdvancedExportWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showExportRestoreJSON(from view: AdvancedExportViewProtocol?)
}
