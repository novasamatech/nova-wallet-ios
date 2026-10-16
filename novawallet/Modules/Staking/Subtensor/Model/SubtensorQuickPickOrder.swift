import Foundation

enum SubtensorQuickPickOrder: CaseIterable, Equatable {
    case poolSize
    case age
    case apy
    case root

    var subnetSort: SubtensorSubnetSort? {
        switch self {
        case .poolSize: return .poolDepth
        case .age: return .age
        case .apy: return .apy
        case .root: return nil
        }
    }
}
