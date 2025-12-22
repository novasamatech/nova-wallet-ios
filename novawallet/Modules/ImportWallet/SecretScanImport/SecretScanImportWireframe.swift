import Foundation

final class SecretScanImportWireframe {
    weak var delegate: SecretScanImportDelegate?

    init(delegate: SecretScanImportDelegate) {
        self.delegate = delegate
    }
}

extension SecretScanImportWireframe: SecretScanImportWireframeProtocol {
    func completeAndPop(
        on view: ControllerBackedProtocol?,
        scan: SecretScanModel
    ) {
        delegate?.didReceive(scan)

        view?.controller.navigationController?.popViewController(animated: true)
    }
}
