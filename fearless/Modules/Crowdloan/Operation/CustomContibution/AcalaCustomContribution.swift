import Foundation
import BigInt

struct CustomContribution: Decodable {
    let amount: BigUInt
    let paraId: ParaId
}

struct AcalaContributionResponse: Decodable {
    let proxyAmount: String
}
