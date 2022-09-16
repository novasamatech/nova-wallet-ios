import Foundation

final class LedgerInstructionsPresenter {
    weak var view: LedgerInstructionsViewProtocol?
    let wireframe: LedgerInstructionsWireframeProtocol

    let applicationConfig: ApplicationConfigProtocol

    init(wireframe: LedgerInstructionsWireframeProtocol, applicationConfig: ApplicationConfigProtocol) {
        self.wireframe = wireframe
        self.applicationConfig = applicationConfig
    }
}

extension LedgerInstructionsPresenter: LedgerInstructionsPresenterProtocol {
    func showHint() {
        guard let view = view else {
            return
        }

        wireframe.showWeb(
            url: applicationConfig.ledgerGuideURL,
            from: view,
            style: .automatic
        )
    }

    func proceed() {
        wireframe.showNetworkSelection(from: view)
    }
}
