import Foundation
import SoraFoundation
import BigInt
import CommonWallet

protocol StakingAmountViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didCompletionAccountSelection()
}

protocol StakingAmountPresenterProtocol: AnyObject {
    func setup()
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectAmountPercentage(_ percentage: Float)
    func selectPayoutAccount()
    func updateAmount(_ newValue: Decimal)
    func selectLearnMore()
    func proceed()
    func close()
}

protocol StakingAmountInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>
    )
    func fetchAccounts()
}

protocol StakingAmountInteractorOutputProtocol: AnyObject {
    func didReceive(accounts: [MetaChainAccountResponse])
    func didReceive(price: PriceData?)
    func didReceive(balance: AccountData?)
    func didReceive(
        paymentInfo: RuntimeDispatchInfo,
        for amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>
    )
    func didReceive(error: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
    func didReceive(minimalBalance: BigUInt)
    func didReceive(minBondAmount: BigUInt?)
    func didReceive(counterForNominators: UInt32?)
    func didReceive(maxNominatorsCount: UInt32?)
}

protocol StakingAmountWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable,
    StakingErrorPresentable {
    func presentAccountSelection(
        _ accounts: [MetaChainAccountResponse],
        selectedAccount: MetaChainAccountResponse,
        delegate: ModalPickerViewControllerDelegate,
        from view: StakingAmountViewProtocol?,
        context: AnyObject?
    )

    func proceed(from view: StakingAmountViewProtocol?, state: InitiatedBonding)

    func close(view: StakingAmountViewProtocol?)
}
