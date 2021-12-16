import Foundation
import SubstrateSdk
import BigInt

struct ParallelContributionResponse: Decodable {
    @StringCodable var paraId: ParaId
    @StringCodable var amount: BigUInt
}
