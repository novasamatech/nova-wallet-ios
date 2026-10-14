import Foundation

protocol SubtensorConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveValidator(viewModel: DisplayAddressViewModel)
    func didReceiveTileIcons(viewModel: SubtensorConfirmTileIconsViewModel)
    func didReceive(viewModel: SubtensorConfirmViewModel)
}

protocol SubtensorConfirmPresenterProtocol: AnyObject {
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
    func loadRootHolds(for hotkeys: [AccountId])
}

protocol SubtensorConfirmInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold])
}

protocol SubtensorConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, MessageSheetPresentable, SubtensorStakingErrorPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable, SubtensorOperationResultPresenting {}
