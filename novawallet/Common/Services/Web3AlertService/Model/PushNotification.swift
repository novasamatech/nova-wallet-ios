import Foundation

enum PushNotification {
    struct AllSettings {
        let notificationsEnabled: Bool
        let accountBased: Web3Alert.LocalSettings
        let topics: TopicSettings
    }

    enum Topic: Codable, Equatable {
        case appCustom
        case chainReferendums(chainId: Web3Alert.ChainId, trackId: TrackIdLocal?)
        case newChainReferendums(chainId: Web3Alert.ChainId, trackId: TrackIdLocal?)

        var identifier: String {
            switch self {
            case .appCustom:
                return "appCustom"
            case let .chainReferendums(chainId, trackId):
                return [
                    "govState",
                    chainId,
                    trackId.map { String($0) }
                ].compactMap { $0 }.joined(separator: "_")
            case let .newChainReferendums(chainId, trackId):
                return [
                    "govNewRef",
                    chainId,
                    trackId.map { String($0) }
                ].compactMap { $0 }.joined(separator: "_")
            }
        }
    }
}
