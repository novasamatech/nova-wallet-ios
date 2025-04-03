import Foundation
import NovaCrypto

final class ExportMnemonicWireframe: ExportMnemonicWireframeProtocol {
    func openConfirmationForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        from view: ControllerBackedProtocol?
    ) {
        guard let confirmationView = ExportMnemonicConfirmViewFactory.createViewForMnemonic(mnemonic) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
