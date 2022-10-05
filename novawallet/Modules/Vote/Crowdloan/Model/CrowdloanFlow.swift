import Foundation

enum CrowdloanFlow: String, Codable {
    case karura = "Karura"
    case bifrost = "Bifrost"
    case acala = "Acala"
    case moonbeam = "Moonbeam"
    case astar = "Astar"
}

extension CrowdloanFlow {
    var supportsPrivateCrowdloans: Bool {
        switch self {
        case .moonbeam:
            return true
        case .karura, .bifrost, .acala, .astar:
            return false
        }
    }
}

extension CrowdloanFlow {
    var supportsAdditionalBonus: Bool {
        switch self {
        case .moonbeam:
            return false
        case .karura, .bifrost, .acala, .astar:
            return true
        }
    }
}
