import Foundation
import SubstrateSdk

struct RemoteChainExternalApi: Equatable, Codable {
    let type: String
    let url: URL
    let parameters: JSON?
}

struct RemoteChainExternalApiSet: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case staking
        case history
        case crowdloans
        case governance
        case goverananceDelegations = "governance-delegations"
    }

    let staking: [RemoteChainExternalApi]?
    let history: [RemoteChainExternalApi]?
    let crowdloans: [RemoteChainExternalApi]?
    let governance: [RemoteChainExternalApi]?
    let goverananceDelegations: [RemoteChainExternalApi]?
}
