import Foundation
import BigInt

protocol CrossChainTransferSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateOriginFee(for amount: BigUInt, recepient: AccountAddress?, weightLimit: BigUInt?)
    func estimateCrossChainFee(for amount: BigUInt, recepient: AccountAddress?)
    func change(recepient: AccountAddress?)
}

protocol CrossChainTransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveSendingAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveOriginFee(result: Result<BigUInt, Error>)
    func didReceiveCrossChainFee(result: Result<FeeWithWeight, Error>)
    func didReceiveSendingAssetPrice(_ price: PriceData?)
    func didReceiveUtilityAssetPrice(_ price: PriceData?)
    func didReceiveUtilityAssetMinBalance(_ value: BigUInt)
    func didReceiveSendingAssetMinBalance(_ value: BigUInt)
    func didReceiveDestinationAssetMinBalance(_ value: BigUInt)
    func didCompleteSetup()
    func didReceiveError(_ error: Error)
}

protocol CrossChainTransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    TransferErrorPresentable, PhishingErrorPresentable, FeeRetryable {
    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    )
}
