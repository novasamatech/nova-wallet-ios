import Foundation

protocol SubtensorStakingConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveValidator(viewModel: DisplayAddressViewModel)
    func didReceiveTileIcons(viewModel: SubtensorConfirmTileIconsViewModel)
    func didReceive(viewModel: SubtensorConfirmViewModel)
}

protocol SubtensorStakingConfirmPresenterProtocol: AnyObject {
    func setup()
    func didAppear()
    func confirm()
    func selectAccount()
    func selectValidator()
    func showSwapRateInfo()
    func showSlippageInfo()
    func showAvgBuyPriceInfo()
    func showYouWillEarnInfo()
    func showNetworkFeeInfo()
}

protocol SubtensorConfirmInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func loadSubnetData()
    func loadCostBasis(for netuid: UInt16)
}

protocol SubtensorConfirmInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?)
    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?)
}

protocol SubtensorStakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, MessageSheetPresentable, SubtensorStakingErrorPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable, SubtensorOperationResultPresenting {}
