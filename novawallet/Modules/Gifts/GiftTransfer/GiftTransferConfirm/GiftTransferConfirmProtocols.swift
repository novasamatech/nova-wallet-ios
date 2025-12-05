import Foundation
import BigInt

protocol GiftTransferConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel)
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveSpendingAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveGiftAmount(viewModel: BalanceViewModelProtocol)
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
        lastFeeDescription: GiftFeeDescription?
    )
}

protocol GiftTransferConfirmInteractorOutputProtocol: GiftTransferSetupInteractorOutputProtocol {
    func didCompleteSubmission(with submissionData: GiftTransferSubmissionResult)
}

protocol GiftTransferConfirmWireframeProtocol: TransferConfirmWireframeProtocol {
    func showGiftShare(
        from view: ControllerBackedProtocol?,
        giftAccountId: AccountId,
        giftId: GiftModel.Id,
        chainAsset: ChainAsset
    )
}
