protocol AdvancedExportViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: AdvancedExportViewLayout.Model)
}

protocol AdvancedExportPresenterProtocol: AnyObject {
    func setup()
}

protocol AdvancedExportInteractorInputProtocol: AnyObject {
    func requestExportOptions(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    )
}

protocol AdvancedExportInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: AdvancedExportData)
}

protocol AdvancedExportWireframeProtocol: AnyObject {}
