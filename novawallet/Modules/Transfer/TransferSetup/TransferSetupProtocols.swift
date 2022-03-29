import BigInt
import CommonWallet
import SoraFoundation

protocol TransferSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveTransferableBalance(viewModel: String)
    func didReceiveChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveAccountState(viewModel: AccountFieldStateViewModel)
    func didReceiveAccountInput(viewModel: InputViewModelProtocol)
}

protocol TransferSetupPresenterProtocol: AnyObject {
    func setup()
    func updateRecepient(partialAddress: String)
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func scanRecepientCode()
    func proceed()
}

protocol TransferSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: BigUInt, recepient: AccountAddress?)
    func change(recepient: AccountAddress?)
}

protocol TransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveSendingAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveFee(result: Result<BigUInt, Error>)
    func didReceiveSendingAssetPrice(_ price: PriceData?)
    func didReceiveUtilityAssetPrice(_ price: PriceData?)
    func didReceiveUtilityAssetMinBalance(_ value: BigUInt)
    func didReceiveSendingAssetMinBalance(_ value: BigUInt)
    func didCompleteSetup()
    func didReceiveError(_ error: Error)
}

protocol TransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    TransferErrorPresentable, PhishingErrorPresentable, FeeRetryable {
    func showConfirmation(
        from view: TransferSetupViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    )

    func showRecepientScan(from view: TransferSetupViewProtocol?, delegate: TransferScanDelegate)

    func hideRecepientScan(from view: TransferSetupViewProtocol?)
}
