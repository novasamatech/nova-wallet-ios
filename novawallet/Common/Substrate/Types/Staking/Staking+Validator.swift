import Foundation
import SubstrateSdk
import BigInt

extension Staking {
    struct ValidatorOverview: Decodable {
        @StringCodable var total: BigUInt
        @StringCodable var own: BigUInt
    }

    struct ValidatorExposurePage: Decodable {
        let others: [IndividualExposure]
    }

    struct ValidatorExposure: Codable {
        @StringCodable var total: BigUInt
        @StringCodable var own: BigUInt
        let others: [IndividualExposure]
    }

    struct IndividualExposure: Codable {
        @BytesCodable var who: AccountId
        @StringCodable var value: BigUInt
    }
}
