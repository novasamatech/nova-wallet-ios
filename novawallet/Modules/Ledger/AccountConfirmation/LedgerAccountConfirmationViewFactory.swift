import Foundation
import SoraFoundation
import SubstrateSdk
import RobinHood

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

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue)
        )

        let interactor = LedgerAccountConfirmationInteractor(
            chain: chain,
            deviceId: deviceId,
            application: application,
            accountsStore: accountsStore,
            requestFactory: requestFactory,
            connection: connection,
            runtimeService: runtimeService,
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

        let view = LedgerAccountConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
