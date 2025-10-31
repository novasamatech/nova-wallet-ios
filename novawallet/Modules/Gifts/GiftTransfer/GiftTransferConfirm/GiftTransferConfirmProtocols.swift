import Foundation
import BigInt

protocol GiftTransferConfirmInteractorInputProtocol: GiftTransferSetupInteractorInputProtocol {
    func submit(
        amount: OnChainTransferAmount<BigUInt>,
        lastFee: BigUInt?
    )
}

protocol GiftTransferConfirmInteractorOutputProtocol: GiftTransferSetupInteractorOutputProtocol {
    func didCompleteSubmition(by sender: ExtrinsicSenderResolution?)
}
