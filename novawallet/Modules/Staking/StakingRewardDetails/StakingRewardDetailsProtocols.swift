import SoraFoundation

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(amountViewModel: BalanceViewModelProtocol)
    func didReceive(validatorViewModel: StackCellViewModel)
    func didReceive(eraViewModel: StackCellViewModel)
}

protocol StakingRewardDetailsPresenterProtocol: AnyObject {
    func setup()
    func handlePayoutAction()
    func handleValidatorAccountAction()
}

protocol StakingRewardDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingRewardDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(priceResult: Result<PriceData?, Error>)
}

protocol StakingRewardDetailsWireframeProtocol: AnyObject, AddressOptionsPresentable {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?, payoutInfo: PayoutInfo)
}

struct StakingRewardDetailsInput {
    let payoutInfo: PayoutInfo
    let activeEra: EraIndex
    let historyDepth: UInt32
    let erasPerDay: UInt32
}
