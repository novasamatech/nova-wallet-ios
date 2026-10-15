import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct BasketClaimPreview: Decodable, Equatable {
        @BytesCodable var hotkey: AccountId
        @StringCodable var accruedTao: Balance
        @StringCodable var redeemableTao: Balance
        @StringCodable var forfeitedTaoEst: Balance
    }
}
