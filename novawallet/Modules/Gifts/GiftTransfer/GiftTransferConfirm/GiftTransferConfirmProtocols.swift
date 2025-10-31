import Foundation
import BigInt

protocol GiftTransferConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel)
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveClaimFee(viewModel: BalanceViewModelProtocol?)
}

protocol GiftTransferConfirmPresenterProtocol: AnyObject {
    func setup()
    func submit()
    func showSenderActions()
}

protocol GiftTransferConfirmInteractorInputProtocol: GiftTransferSetupInteractorInputProtocol {
    func submit(
        amount: OnChainTransferAmount<BigUInt>,
        lastFee: BigUInt?
    )
}

protocol GiftTransferConfirmInteractorOutputProtocol: GiftTransferSetupInteractorOutputProtocol {
    func didCompleteSubmition(by sender: ExtrinsicSenderResolution?)
}
