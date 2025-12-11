import Foundation

protocol SecretScanImportDelegate: AnyObject {
    func didReceive(_ scan: SecretScanModel)
}

protocol SecretScanImportWireframeProtocol {
    func completeAndPop(
        on view: ControllerBackedProtocol?,
        scan: SecretScanModel
    )
}
