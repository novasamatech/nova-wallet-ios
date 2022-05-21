import Foundation
import BigInt

protocol ParaStkStakeConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
}

protocol ParaStkStakeConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectAccount()
    func selectCollator()
    func confirm()
}

protocol ParaStkStakeConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func confirm()
}

protocol ParaStkStakeConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?)
    func didReceiveMinTechStake(_ minStake: BigUInt)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveStakingDuration(_ duration: ParachainStakingDuration)
    func didReceiveError(_ error: Error)
}

protocol ParaStkStakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable {}
