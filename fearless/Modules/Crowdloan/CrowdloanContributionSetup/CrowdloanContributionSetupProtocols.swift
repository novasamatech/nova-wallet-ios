import Foundation
import CommonWallet
import BigInt
import SoraFoundation

protocol CrowdloanContributionSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveCrowdloan(viewModel: CrowdloanContributionSetupViewModel)
    func didReceiveEstimatedReward(viewModel: String?)
    func didReceiveBonus(viewModel: String?)
    func didReceiveRewardDestination(viewModel: AccountInfoViewModel)
}

protocol CrowdloanContributionSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
    func presentLearnMore()
    func presentAdditionalBonuses()
    func presentRewardDestination()
}

protocol CrowdloanContributionSetupInteractorInputProtocol: CrowdloanContributionInteractorInputProtocol {}

protocol CrowdloanContributionSetupInteractorOutputProtocol: CrowdloanContributionInteractorOutputProtocol {}

protocol CrowdloanContributionSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    CrowdloanErrorPresentable, WebPresentable, AddressOptionsPresentable {
    func showConfirmation(
        from view: CrowdloanContributionSetupViewProtocol?,
        paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?
    )

    func showAdditionalBonus(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    )
}
