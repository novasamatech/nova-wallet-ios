import Foundation
import Operation_iOS

extension PushNotification {
    struct TopicSettings: Codable, Equatable, Identifiable {
        var identifier: String { Self.getIdentifier() }
        let topics: Set<PushNotification.Topic>

        var isGovernanceOn: Bool {
            topics.contains {
                switch $0 {
                case .chainReferendums, .newChainReferendums:
                    return true
                case .appCustom:
                    return false
                }
            }
        }

        var isAnnouncementsOn: Bool {
            topics.contains {
                switch $0 {
                case .chainReferendums, .newChainReferendums:
                    return false
                case .appCustom:
                    return true
                }
            }
        }

        init(topics: Set<PushNotification.Topic>) {
            self.topics = topics
        }

        static func getIdentifier() -> String {
            "LocalNotificationTopicSettingsIdentifier"
        }
    }

    enum Topic: Codable, Hashable, Equatable {
        static let componentsSeparator = "_"

        case appCustom
        case chainReferendums(chainId: Web3Alert.LocalChainId, trackId: TrackIdLocal)
        case newChainReferendums(chainId: Web3Alert.LocalChainId, trackId: TrackIdLocal)

        var remoteId: String {
            switch self {
            case .appCustom:
                return "appCustom"
            case let .chainReferendums(chainId, trackId):
                let remoteChainId = Web3Alert.createRemoteChainId(from: chainId)
                return [
                    "govState",
                    remoteChainId,
                    String(trackId)
                ].joined(separator: Self.componentsSeparator)
            case let .newChainReferendums(chainId, trackId):
                let remoteChainId = Web3Alert.createRemoteChainId(from: chainId)
                return [
                    "govNewRef",
                    remoteChainId,
                    String(trackId)
                ].joined(separator: Self.componentsSeparator)
            }
        }
    }
}

extension PushNotification.TopicSettings {
    func byTogglingAnnouncements() -> PushNotification.TopicSettings {
        let hasAppCustom = topics.contains(.appCustom)

        let newTopics = hasAppCustom ? topics.subtracting([.appCustom]) : topics.union([.appCustom])

        return .init(topics: newTopics)
    }
}
