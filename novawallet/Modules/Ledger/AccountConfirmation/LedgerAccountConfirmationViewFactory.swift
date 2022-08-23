import Foundation
import SoraFoundation

struct LedgerAccountConfirmationViewFactory {
    static func createView(
        chain: ChainModel,
        deviceId: UUID,
        application: LedgerApplication,
        accountsStore: LedgerAccountsStore
    ) -> LedgerAccountConfirmationViewProtocol? {
        guard let utilityAsset = chain.utilityAsset() else {
            return nil
        }

        let interactor = LedgerAccountConfirmationInteractor(
            chain: chain,
            deviceId: deviceId,
            application: application,
            accountsStore: accountsStore,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = LedgerAccountConfirmationWireframe()

        let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(
            for: utilityAsset.displayInfo
        )

        let presenter = LedgerAccountConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            tokenFormatter: tokenFormatter,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerAccountConfirmationViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
