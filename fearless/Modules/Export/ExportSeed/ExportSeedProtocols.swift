protocol ExportSeedInteractorInputProtocol: AnyObject {
    func fetchExportDataForAddress()
}

protocol ExportSeedInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: ExportSeedData)
    func didReceive(error: Error)
}

protocol ExportSeedWireframeProtocol: ExportGenericWireframeProtocol {}
