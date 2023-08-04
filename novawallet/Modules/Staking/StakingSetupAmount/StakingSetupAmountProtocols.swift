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
    func remakeRecommendationSetup()

    func estimateFee(for amount: BigUInt)
    func updateRecommendation(for amount: BigUInt)
    func replaceWithManual(option: SelectedStakingOption)
}

protocol StakingSetupAmountInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance)
    func didReceive(fee: BigUInt?, stakingOption: SelectedStakingOption, amount: BigUInt)
    func didReceive(recommendation: RelaychainStakingRecommendation, amount: BigUInt)
    func didReceive(error: StakingSetupAmountError)
}

protocol StakingSetupAmountWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable, CommonRetryable {
    func showStakingTypeSelection(from view: ControllerBackedProtocol?)
}

enum StakingSetupAmountError: Error {
    case assetBalance(Error)
    case price(Error)
    case fee(Error)
    case recommendation(Error)
}
