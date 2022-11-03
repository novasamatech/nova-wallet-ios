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
        guard
            let chain = state.settings.value,
            let currencyManager = CurrencyManager.shared,
            let assetInfo = chain.utilityAssetDisplayInfo() else {
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

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = ReferendumFullDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            referendum: referendum,
            actionDetails: actionDetails,
            identities: identities,
            balanceViewModelFactory: balanceViewModelFactory,
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
