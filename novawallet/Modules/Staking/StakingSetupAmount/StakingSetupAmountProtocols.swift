import Foundation
import BigInt

protocol StakingSetupAmountViewProtocol: ControllerBackedProtocol {
    func didReceive(estimatedRewards: LoadableViewModelState<TitleHorizontalMultiValueView.Model>?)
    func didReceive(balance: TitleHorizontalMultiValueView.Model)
    func didReceive(title: String)
    func didReceiveButtonState(title: String, enabled: Bool)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceive(stakingType: LoadableViewModelState<StakingTypeViewModel>?)
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
    func stakingTypeRecomendation(for amount: Decimal)
}

protocol StakingSetupAmountInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance)
    func didReceive(error: StakingSetupAmountError)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(minimalBalance: BigUInt)
    func didReceive(stakingType: SelectedStakingType)
}

protocol StakingSetupAmountWireframeProtocol: AnyObject {
    func showStakingTypeSelection(from view: ControllerBackedProtocol?)
}

enum StakingSetupAmountError: Error {
    case assetBalance(Error)
    case price(Error)
    case fetchCoderFactory(Error)
    case fee(Error)
    case existensialDeposit(Error)
    case minNominatorBond(Error)
    case counterForNominators(Error)
    case maxNominatorsCount(Error)
    case bagListSize(Error)
    case networkInfo(Error)
    case calculator(Error)
}
