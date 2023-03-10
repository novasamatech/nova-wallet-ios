import BigInt

protocol StakingRebagConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCurrentRebag(viewModel: String)
    func didReceiveNextRebag(viewModel: String)
    func didReceiveHints(viewModel: [String])
    func didStartLoading()
    func didStopLoading()
    func didReceiveConfirmState(isAvailable: Bool)
}

protocol StakingRebagConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingRebagConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func refreshFee(stashItem: StashItem)
    func remakeStashItemSubscription()
    func remakeAccountBalanceSubscription()
    func submit(stashItem: StashItem)
}

protocol StakingRebagConfirmInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(fee: BigUInt?)
    func didReceive(networkInfo: NetworkStakingInfo?)
    func didReceive(currentBagListNode: BagList.Node?)
    func didReceive(ledgerInfo: StakingLedger?)
    func didReceive(totalIssuance: BigUInt?)
    func didReceive(stashItem: StashItem?)

    func didReceive(error: StakingRebagConfirmError)
    func didSubmitRebag()
}

protocol StakingRebagConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, StakingErrorPresentable, CommonRetryable, MessageSheetPresentable {
    func complete(from view: StakingRebagConfirmViewProtocol?, locale: Locale)
}
