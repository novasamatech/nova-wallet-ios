import Foundation
import SubstrateSdk
import SoraFoundation

struct ReferendumFullDetailsViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity]
    ) -> ReferendumFullDetailsViewProtocol? {
        guard let chain = state.settings.value,
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = ReferendumFullDetailsWireframe()
        let processingOperationFactory = PrettyPrintedJSONOperationFactory(preprocessor: ExtrinsicJSONProcessor())

        let interactor = ReferendumFullDetailsInteractor(
            chain: chain,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            processingOperationFactory: processingOperationFactory,
            referendumAction: actionDetails,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let presenter = ReferendumFullDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainIconGenerator: PolkadotIconGenerator(),
            chain: chain,
            referendum: referendum,
            actionDetails: actionDetails,
            identities: identities,
            localizationManager: LocalizationManager.shared,
            currencyManager: currencyManager,
            assetFormatterFactory: AssetBalanceFormatterFactory()
        )
        interactor.presenter = presenter
        let view = ReferendumFullDetailsViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
