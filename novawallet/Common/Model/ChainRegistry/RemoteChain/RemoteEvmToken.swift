import Foundation
import SubstrateSdk

struct RemoteEvmToken: Codable {
    let symbol: String
    let precision: Int
    let name: String
    let priceId: String?
    let icon: String?
    let instances: [Instance]

    struct Instance: Codable {
        let chainId: String
        let contractAddress: String
        let buyProviders: JSON?
        let sellProviders: JSON?
    }
}
