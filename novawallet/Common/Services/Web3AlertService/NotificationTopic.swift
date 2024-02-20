import Foundation

enum NotificationTopic: Codable, Equatable {
    case appUpdates
    case chainReferendums(chainId: String, trackId: String?)
    case newChainReferendums(chainId: String, trackId: String?)

    var identifier: String {
        switch self {
        case .appUpdates:
            return "appUpdates"
        case let .chainReferendums(chainId, trackId):
            return [
                "govState",
                chainId,
                trackId
            ].compactMap { $0 }.joined(separator: ":")
        case let .newChainReferendums(chainId, trackId):
            return [
                "govNewRef",
                chainId,
                trackId
            ].compactMap { $0 }.joined(separator: ":")
        }
    }
}
