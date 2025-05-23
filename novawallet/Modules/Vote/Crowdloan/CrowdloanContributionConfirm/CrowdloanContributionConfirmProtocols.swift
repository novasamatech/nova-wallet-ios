import Foundation_iOS
import BigInt

protocol CrowdloanContributionConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCrowdloan(viewModel: CrowdloanContributeConfirmViewModel)
    func didReceiveEstimatedReward(viewModel: String?)
    func didReceiveBonus(viewModel: String?)
    func didReceiveRewardDestination(viewModel: CrowdloanRewardDestinationVM)
}

protocol CrowdloanContributionConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func presentAccountOptions()
    func presentRewardDestination()
}

protocol CrowdloanContributionConfirmInteractorInputProtocol: CrowdloanContributionInteractorInputProtocol {
    func estimateFee(for contribution: BigUInt)
    func submit(contribution: BigUInt)
}

protocol CrowdloanContributionConfirmInteractorOutputProtocol: CrowdloanContributionInteractorOutputProtocol {
    func didSubmitContribution(result: Result<String, Error>)
    func didReceiveDisplayAddress(result: Result<DisplayAddress, Error>)
    func didReceiveRewardDestinationAddress(_ address: AccountAddress)
}

protocol CrowdloanContributionConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    CrowdloanErrorPresentable, AddressOptionsPresentable, MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(on view: CrowdloanContributionConfirmViewProtocol?)
}
