import Foundation
import BigInt

protocol ParaStkStakeConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
    func didReceiveHints(viewModel: [String])
}

protocol ParaStkStakeConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectAccount()
    func selectCollator()
    func confirm()
}

protocol ParaStkStakeConfirmInteractorInputProtocol: AnyObject {
    func setup()

    func estimateFee(
        _ amount: BigUInt,
        collator: AccountId,
        collatorDelegationsCount: UInt32,
        delegationsCount: UInt32,
        existingBond: BigUInt?
    )

    func confirm(
        _ amount: BigUInt,
        collator: AccountId,
        collatorDelegationsCount: UInt32,
        delegationsCount: UInt32,
        existingBond: BigUInt?
    )
}

protocol ParaStkStakeConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?)
    func didReceiveMinTechStake(_ minStake: BigUInt)
    func didReceiveMinDelegationAmount(_ amount: BigUInt)
    func didReceiveMaxDelegations(_ maxDelegations: UInt32)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveStakingDuration(_ duration: ParachainStakingDuration)
    func didCompleteExtrinsicSubmission(for result: Result<String, Error>)
    func didReceiveError(_ error: Error)
}

protocol ParaStkStakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable {
    func complete(on view: ParaStkStakeConfirmViewProtocol?, locale: Locale)
}
