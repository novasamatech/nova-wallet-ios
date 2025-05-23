import Foundation
import Foundation_iOS

import BigInt

protocol StakingMainViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: StakingMainViewModel)
    func didRecieveNetworkStakingInfo(viewModel: NetworkStakingInfoViewModel)
    func didReceiveStakingState(viewModel: StakingViewState)
    func expandNetworkInfoView(_ isExpanded: Bool)
    func didReceiveStatics(viewModel: StakingMainStaticViewModelProtocol)
    func didReceiveSelectedEntity(_ entity: StakingSelectedEntityViewModel)
    func didEditRewardFilters()
}

protocol StakingMainPresenterProtocol: AnyObject {
    func setup()
    func performRedeemAction()
    func performRebondAction()
    func performClaimRewards()
    func networkInfoViewDidChangeExpansion(isExpanded: Bool)
    func performManageAction(_ action: StakingManageOption)
    func performAlertAction(_ alert: StakingAlert)
    func selectPeriod()
}

protocol StakingMainInteractorInputProtocol: AnyObject {
    func setup()
    func saveNetworkInfoViewExpansion(isExpanded: Bool)
    func save(filter: StakingRewardFiltersPeriod)
}

protocol StakingMainInteractorOutputProtocol: AnyObject {
    func didReceiveExpansion(_ isExpanded: Bool)
    func didReceiveRewardFilter(_ filter: StakingRewardFiltersPeriod)
}

protocol StakingMainWireframeProtocol: AlertPresentable, NoAccountSupportPresentable {
    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel)
    func showPeriodSelection(
        from view: ControllerBackedProtocol?,
        initialState: StakingRewardFiltersPeriod?,
        delegate: StakingRewardFiltersDelegate,
        completion: @escaping () -> Void
    )
}

protocol StakingMainChildPresenterProtocol: AnyObject {
    func setup()
    func performRedeemAction()
    func performRebondAction()
    func performClaimRewards()
    func performManageAction(_ action: StakingManageOption)
    func performAlertAction(_ alert: StakingAlert)
    func selectPeriod(_ period: StakingRewardFiltersPeriod)
}
