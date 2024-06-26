import Foundation
import SoraFoundation

struct LedgerInstructionsViewFactory {
    static func createView(
        for flow: WalletCreationFlow,
        appType: LedgerAppType
    ) -> LedgerInstructionsViewProtocol? {
        let wireframe = LedgerInstructionsWireframe(flow: flow, appType: appType)

        let presenter = LedgerInstructionsPresenter(
            wireframe: wireframe,
            applicationConfig: ApplicationConfig.shared
        )

        let view = LedgerInstructionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
