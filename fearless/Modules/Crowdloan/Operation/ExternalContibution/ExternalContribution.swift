import Foundation
import BigInt

struct ExternalContribution: Decodable {
    let amount: BigUInt
    let paraId: ParaId
}
