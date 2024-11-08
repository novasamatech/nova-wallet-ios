enum AssetListGroupsStyle: String {
    case networks
    case tokens

    mutating func toggle() {
        switch self {
        case .networks: self = .tokens
        case .tokens: self = .networks
        }
    }
}
