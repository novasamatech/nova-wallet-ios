import Foundation
import Foundation_iOS
import Operation_iOS

protocol CrowdloanUnlockViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol CrowdloanUnlockPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol CrowdloanUnlockInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for unlocks: Set<CrowdloanUnlockItem>)
    func submit(unlocks: Set<CrowdloanUnlockItem>)
}

protocol CrowdloanUnlockInteractorOutputProtocol: AnyObject {
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceiveFeeResult(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>)
    func didReceiveExistentialDeposit(_ existentialDeposit: Balance?)
}

protocol CrowdloanUnlockWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable,
    AddressOptionsPresentable,
    MessageSheetPresentable,
    ModalAlertPresenting,
    CrowdloanErrorPresentable,
    ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
