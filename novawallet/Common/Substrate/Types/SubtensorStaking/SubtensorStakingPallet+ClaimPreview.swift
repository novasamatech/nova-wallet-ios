import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct BasketClaimPreview: Decodable, Equatable {
        @BytesCodable var hotkey: AccountId
        @StringCodable var owedShares: UInt64
        @StringCodable var accruedTao: Balance
        @StringCodable var redeemableTao: Balance
        @StringCodable var forfeitedTaoEst: Balance
        @StringCodable var rows: UInt32
        @StringCodable var rowsToSell: UInt32
        @StringCodable var dustRows: UInt32
        @StringCodable var swept: UInt32
        @StringCodable var flushedCredits: UInt32
    }
}
