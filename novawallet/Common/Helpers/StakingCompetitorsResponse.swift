import Foundation

struct StakingCompetitorsResponse: Decodable {
    let version: Int
    let domains: [String]
}
