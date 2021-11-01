import Foundation
import SoraFoundation

struct CrowdloanYourContributionsViewInput {
    let crowdloans: [Crowdloan]
    let viewInfo: CrowdloansViewInfo
    let chainAsset: ChainAssetDisplayInfo
}

enum CrowdloanYourContributionsViewFactory {
    static func createView(
        input: CrowdloanYourContributionsViewInput
    ) -> CrowdloanYourContributionsViewProtocol? {
        let interactor = CrowdloanYourContributionsInteractor()
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
