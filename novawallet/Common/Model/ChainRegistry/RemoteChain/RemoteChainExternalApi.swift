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
        case stakingRewards = "staking-rewards"
        case history
        case crowdloans
        case governance
        case multisig
        case goverananceDelegations = "governance-delegations"
        case referendumSummary = "referendum-summary"
    }

    let staking: [RemoteChainExternalApi]?
    let stakingRewards: [RemoteChainExternalApi]?
    let history: [RemoteChainExternalApi]?
    let crowdloans: [RemoteChainExternalApi]?
    let governance: [RemoteChainExternalApi]?
    let goverananceDelegations: [RemoteChainExternalApi]?
    let referendumSummary: [RemoteChainExternalApi]?
    let multisig: [RemoteChainExternalApi]?
}
