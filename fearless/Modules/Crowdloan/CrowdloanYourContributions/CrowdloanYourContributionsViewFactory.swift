import Foundation
import SoraFoundation
import SoraKeystore

struct CrowdloanYourContributionsViewInput {
    let crowdloans: [Crowdloan]
    let contributions: CrowdloanContributionDict
    let displayInfo: CrowdloanDisplayInfoDict?
    let chainAsset: ChainAssetDisplayInfo
}

enum CrowdloanYourContributionsViewFactory {
    static func createView(
        input: CrowdloanYourContributionsViewInput,
        sharedState: CrowdloanSharedState
    ) -> CrowdloanYourContributionsViewProtocol? {
        guard
            let chain = sharedState.settings.value,
            let selectedMetaAccount = SelectedWalletSettings.shared.value
        else { return nil }

        let interactor = CrowdloanYourContributionsInteractor(
            chain: chain,
            selectedMetaAccount: selectedMetaAccount,
            operationManager: OperationManagerFacade.sharedManager,
            crowdloanOffchainProviderFactory: sharedState.crowdloanOffchainProviderFactory
        )

        let wireframe = CrowdloanYourContributionsWireframe()

        let viewModelFactory = CrowdloanYourContributionsVMFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = CrowdloanYourContributionsPresenter(
            input: input,
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            wireframe: wireframe
        )

        let view = CrowdloanYourContributionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
