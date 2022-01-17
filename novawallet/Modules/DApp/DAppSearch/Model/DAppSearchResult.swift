import Foundation

enum DAppSearchResult {
    case query(string: String)
    case dApp(model: DApp)

    var dApp: DApp? {
        switch self {
        case .query:
            return nil
        case let .dApp(model):
            return model
        }
    }
}
