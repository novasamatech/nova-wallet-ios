import Foundation
import Operation_iOS

protocol GiftReclaimWrapperFactoryProtocol {
    func reclaimGift(
        _ gift: GiftModel,
        selectedWallet: MetaAccountModel
    ) -> CompoundOperationWrapper<Void>
}
