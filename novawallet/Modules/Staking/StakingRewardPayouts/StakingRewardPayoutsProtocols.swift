import Foundation_iOS
import UIKit_iOS

protocol StakingRewardPayoutsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with state: StakingRewardPayoutsViewState)
}

enum StakingRewardPayoutsViewState {
    case loading(Bool)
    case payoutsList(LocalizableResource<StakingPayoutViewModel>)
    case emptyList
    case error(LocalizableResource<String>)
}

protocol StakingRewardPayoutsPresenterProtocol: AnyObject {
    func setup()
    func handleSelectedHistory(at index: Int)
    func handlePayoutAction()
    func reload()
    func getTimeLeftString(at index: Int) -> LocalizableResource<NSAttributedString>?
}

protocol StakingRewardPayoutsInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

protocol StakingRewardPayoutsInteractorOutputProtocol: AnyObject {
    func didReceive(result: Result<PayoutsInfo, PayoutRewardsServiceError>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
}

protocol StakingRewardPayoutsWireframeProtocol: AnyObject {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        historyDepth: UInt32,
        eraCountdown: EraCountdown
    )

    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        from view: ControllerBackedProtocol?
    )
}

protocol StakingPayoutViewModelFactoryProtocol {
    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?
    ) -> LocalizableResource<StakingPayoutViewModel>

    func timeLeftString(
        at index: Int,
        payoutsInfo: PayoutsInfo,
        eraCountdown: EraCountdown?
    ) -> LocalizableResource<NSAttributedString>
}
