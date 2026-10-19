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

protocol SubtensorConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, MessageSheetPresentable, SubtensorErrorPresentable, SubtensorClaimErrorPresentable,
    AddressOptionsPresentable, SubtensorInfoSheetPresentable, SubtensorValidatorInfoPresentable,
    SubtensorOperationResultPresenting {}
