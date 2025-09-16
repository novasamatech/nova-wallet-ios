import Foundation
import Foundation_iOS

import BigInt

protocol StakingBondMoreConfirmationViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingBondMoreConfirmViewModel)
    func didReceiveAmount(viewModel: LocalizableResource<BalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingBondMoreConfirmationPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingBondMoreConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func submit(for amount: Decimal)
    func estimateFee(for amount: Decimal)
}

protocol StakingBondMoreConfirmationOutputProtocol: AnyObject {
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveStash(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveStakingMigratedToHold(result: Result<Bool, Error>)
    func didSubmitBonding(result: Result<ExtrinsicSubmittedModel, Error>)
}

protocol StakingBondMoreConfirmationWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {}
