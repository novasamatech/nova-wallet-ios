import Foundation
import SubstrateSdk
import BigInt

struct Identity: Decodable {
    let info: IdentityInfo
}

struct IdentityInfo: Decodable {
    let display: ChainData
    let legal: ChainData
    let web: ChainData
    let riot: ChainData
    let email: ChainData
    let image: ChainData
    let twitter: ChainData
}
