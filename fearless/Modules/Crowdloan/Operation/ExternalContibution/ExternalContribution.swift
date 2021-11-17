import Foundation
import BigInt

struct ExternalContribution: Decodable {
    let source: String?
    let amount: BigUInt
    let paraId: ParaId
}
