import Foundation
import BigInt
import SubstrateSdk

extension SubtensorPallet {
    struct BasketClaimPreview: Decodable, Equatable {
        @BytesCodable var hotkey: AccountId
        @StringCodable var redeemableTao: Balance
        @StringCodable var forfeitedTaoEst: Balance
    }
}
