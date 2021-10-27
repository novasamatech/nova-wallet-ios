import Foundation

enum CrowdloanFlow: String, Codable {
    case karura = "Karura"
    case bifrost = "Bifrost"
    case acala = "Acala"
    case moonbeam = "Moonbeam"
}

extension CrowdloanFlow {
    var supportsPrivateCrowdloans: Bool {
        switch self {
        case .moonbeam:
            return true
        case .karura, .bifrost, .acala:
            return false
        }
    }
}

extension CrowdloanFlow {
    var supportsAdditionalBonus: Bool {
        switch self {
        case .moonbeam:
            return false
        case .karura, .bifrost, .acala:
            return true
        }
    }
}
