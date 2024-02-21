import Foundation

enum NotificationTopic: Codable, Equatable {
    case appUpdates
    case chainReferendums(chainId: String, trackId: TrackIdLocal?)
    case newChainReferendums(chainId: String, trackId: TrackIdLocal?)

    var identifier: String {
        switch self {
        case .appUpdates:
            return "appUpdates"
        case let .chainReferendums(chainId, trackId):
            return [
                "govState",
                chainId,
                trackId.map { String($0) }
            ].compactMap { $0 }.joined(separator: ":")
        case let .newChainReferendums(chainId, trackId):
            return [
                "govNewRef",
                chainId,
                trackId.map { String($0) }
            ].compactMap { $0 }.joined(separator: ":")
        }
    }
}
