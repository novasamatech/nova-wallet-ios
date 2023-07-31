import Foundation
import BigInt

protocol StakingSetupAmountViewProtocol: ControllerBackedProtocol {
    func didReceive(estimatedRewards: LoadableViewModelState<TitleHorizontalMultiValueView.RewardModel>?)
    func didReceive(balance: TitleHorizontalMultiValueView.RewardModel)
    func didReceive(title: String)
    func didReceiveButtonState(title: String, enabled: Bool)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceive(stakingType: LoadableViewModelState<StakingTypeChoiceViewModel>)
}

protocol StakingSetupAmountPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func selectStakingType()
}

protocol StakingSetupAmountInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>
    )
}

protocol StakingSetupAmountInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance)
    func didReceive(error: StakingSetupAmountError)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
}

protocol StakingSetupAmountWireframeProtocol: AnyObject {
    func showStakingTypeSelection(from view: ControllerBackedProtocol?)
}

enum StakingSetupAmountError: Error {
    case assetBalance(Error)
    case price(Error)
    case fetchCoderFactory(Error)
    case fee(Error)
}
