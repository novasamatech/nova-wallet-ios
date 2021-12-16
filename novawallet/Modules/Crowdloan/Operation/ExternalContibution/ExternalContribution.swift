import Foundation
import BigInt

struct ExternalContribution: Codable, Equatable {
    let source: String?
    let amount: BigUInt
    let paraId: ParaId
}
