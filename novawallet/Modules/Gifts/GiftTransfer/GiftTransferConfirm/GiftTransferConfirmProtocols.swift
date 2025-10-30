import Foundation
import BigInt

protocol GiftTransferConfirmInteractorInputProtocol: GiftTransferSetupInteractorInputProtocol {
    func submit(
        amount: OnChainTransferAmount<BigUInt>,
        lastFee: BigUInt?
    )
}
