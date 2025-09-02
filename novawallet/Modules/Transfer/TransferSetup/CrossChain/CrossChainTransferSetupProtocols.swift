import Foundation
import BigInt

protocol CrossChainTransferSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateOriginFee(for amount: BigUInt, recepient: AccountId?)
    func estimateCrossChainFee(for amount: BigUInt, recepient: AccountId?)
    func change(recepient: AccountId?)
}

protocol CrossChainTransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveSendingAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveOriginFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveCrossChainFee(result: Result<XcmFeeModelProtocol, Error>)
    func didReceiveSendingAssetPrice(_ price: PriceData?)
    func didReceiveUtilityAssetPrice(_ price: PriceData?)
    func didReceiveOriginUtilityMinBalance(_ value: BigUInt)
    func didReceiveOriginSendingMinBalance(_ value: BigUInt)
    func didReceiveDestSendingExistence(_ value: AssetBalanceExistence)
    func didReceiveDestUtilityMinBalance(_ value: BigUInt)
    func didReceiveRequiresOriginKeepAlive(_ value: Bool)
    func didCompleteSetup(result: Result<Void, Error>)
    func didReceiveError(_ error: Error)
}

protocol CrossChainTransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    TransferErrorPresentable, PhishingErrorPresentable, FeeRetryable,
    CommonRetryable {
    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    )
}
