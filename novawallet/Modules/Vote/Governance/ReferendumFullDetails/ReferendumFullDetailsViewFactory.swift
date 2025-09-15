import Foundation
import SubstrateSdk
import Foundation_iOS

struct ReferendumFullDetailsViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        metadata: ReferendumMetadataLocal?,
        identities: [AccountAddress: AccountIdentity]
    ) -> ReferendumFullDetailsViewProtocol? {
        guard
            let chain = state.settings.value?.chain,
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

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = ReferendumFullDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            referendum: referendum,
            actionDetails: actionDetails,
            metadata: metadata,
            identities: identities,
            balanceViewModelFacade: balanceViewModelFacade,
            addressViewModelFactory: DisplayAddressViewModelFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        interactor.presenter = presenter

        let view = ReferendumFullDetailsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
