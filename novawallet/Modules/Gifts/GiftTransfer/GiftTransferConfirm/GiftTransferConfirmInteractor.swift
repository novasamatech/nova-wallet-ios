import Foundation
import BigInt

final class GiftTransferConfirmInteractor: GiftTransferInteractor {}

extension GiftTransferConfirmInteractor: GiftTransferConfirmInteractorInputProtocol {
    func submit(
        amount _: OnChainTransferAmount<BigUInt>,
        lastFee _: BigUInt?
    ) {}
}
