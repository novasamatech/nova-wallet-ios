import BigInt
import Foundation

protocol GiftTransferSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: OnChainTransferAmount<BigUInt>)
}

protocol GiftTransferSetupInteractorOutputProtocol: OnChainTransferSetupInteractorOutputProtocol {}

protocol GiftTransferSetupWireframeProtocol: AlertPresentable,
                                             ErrorPresentable,
                                             TransferErrorPresentable,
                                             PhishingErrorPresentable,
                                             FeeRetryable {
    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>,
        recepient: AccountAddress
    )
}
