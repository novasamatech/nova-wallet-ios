import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

final class AcalaContributionConfirmPresenter: CrowdloanContributionConfirmPresenter {
    let contributionMethod: AcalaContributionMethod

    init(
        contributionMethod: AcalaContributionMethod,
        interactor: CrowdloanContributionConfirmInteractorInputProtocol,
        wireframe: CrowdloanContributionConfirmWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        dataValidatingFactory: CrowdloanDataValidatorFactoryProtocol,
        inputAmount: Decimal,
        bonusRate: Decimal?,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.contributionMethod = contributionMethod
        super.init(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            inputAmount: inputAmount,
            bonusRate: bonusRate,
            assetInfo: assetInfo,
            localizationManager: localizationManager,
            chain: chain,
            logger: logger
        )
    }

    override func didReceiveMinimumContribution(result: Result<BigUInt, Error>) {
        switch result {
        case .success:
            switch contributionMethod {
            case .liquid:
                minimumContribution = BigUInt(1e+10)
                provideAssetVewModel()
            case .direct:
                super.didReceiveMinimumContribution(result: result)
            }
        case .failure:
            super.didReceiveMinimumContribution(result: result)
        }
    }
}
