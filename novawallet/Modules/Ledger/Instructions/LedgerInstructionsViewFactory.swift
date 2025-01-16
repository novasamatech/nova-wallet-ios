import Foundation
import Foundation_iOS

struct LedgerInstructionsViewFactory {
    static func createView(
        for flow: WalletCreationFlow,
        walletLedgerType: LedgerWalletType
    ) -> LedgerInstructionsViewProtocol? {
        let wireframe = LedgerInstructionsWireframe(
            flow: flow,
            walletLedgerType: walletLedgerType
        )

        let presenter = LedgerInstructionsPresenter(
            wireframe: wireframe,
            walletType: walletLedgerType,
            isGenericAvailable: ChainRegistryFacade.sharedRegistry.genericLedgerAvailable(),
            applicationConfig: ApplicationConfig.shared,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerInstructionsViewController(
            presenter: presenter,
            walletType: walletLedgerType,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
