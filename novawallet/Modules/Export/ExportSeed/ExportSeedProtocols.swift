protocol ExportSeedInteractorInputProtocol: AnyObject {
    func fetchExportData()
}

protocol ExportSeedInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: ExportSeedData)
    func didReceive(error: Error)
}

protocol ExportSeedWireframeProtocol: ExportGenericWireframeProtocol {}
