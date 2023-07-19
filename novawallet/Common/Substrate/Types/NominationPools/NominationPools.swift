import Foundation
import SubstrateSdk
import BigInt

enum NominationPools {
    typealias PoolId = UInt32

    struct PoolMember: Decodable {
        @StringCodable var poolId: PoolId
        @StringCodable var points: BigUInt
        @StringCodable var lastRecordedRewardCounter: BigUInt
        let unbondingEras: [SupportPallet.KeyValue<StringScaleMapper<EraIndex>, StringScaleMapper<BigUInt>>]
    }
    
    enum PoolState: Decodable {
        case open
        case blocked
        case destroying
        case unsuppored
        
        init(from decoder: Decoder) throws {
            let singleContainer = try decoder.singleValueContainer()
            
            let rawValue = try singleContainer.decode(String.self)
            
            switch rawValue {
            case "Open":
                self = .open
            case "Blocked":
                self = .blocked
            case "Destroying":
                self = .destroying
            default:
                self = .unsuppored
            }
        }
    }
    
    struct BondedPool: Decodable {
        @StringCodable var points: BigUInt
        let poolState: PoolState
    }

    enum AccountType: UInt8 {
        case bonded
        case reward
    }
}
