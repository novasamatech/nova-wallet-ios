import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct SubnetPrice: Decodable, Equatable {
        @StringCodable var netuid: UInt16
        @StringCodable var price: Balance
    }

    struct SimSwapResult: Decodable, Equatable {
        @StringCodable var taoAmount: Balance
        @StringCodable var alphaAmount: Balance
        @StringCodable var taoFee: Balance
        @StringCodable var alphaFee: Balance
        @StringCodable var taoSlippage: Balance
        @StringCodable var alphaSlippage: Balance
    }
}
