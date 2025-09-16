import Operation_iOS

struct GovernanceNotificationsModel {
    let newReferendum: [ChainModel.Id: Set<TrackIdLocal>]
    let referendumUpdate: [ChainModel.Id: Set<TrackIdLocal>]

    func isNewReferendumNotificationEnabled(for chainId: ChainModel.Id) -> Bool {
        newReferendum[chainId] != nil
    }

    func isReferendumUpdateNotificationEnabled(for chainId: ChainModel.Id) -> Bool {
        referendumUpdate[chainId] != nil
    }

    func isNotificationEnabled(for chainId: ChainModel.Id) -> Bool {
        isNewReferendumNotificationEnabled(for: chainId) ||
            isReferendumUpdateNotificationEnabled(for: chainId)
    }

    func tracks(for chainId: ChainModel.Id) -> Set<TrackIdLocal>? {
        newReferendum[chainId] ?? referendumUpdate[chainId]
    }

    func enablingNewReferendumNotification(
        for tracks: Set<TrackIdLocal>,
        chainId: ChainModel.Id
    ) -> GovernanceNotificationsModel {
        var updatedNewReferendum = newReferendum
        updatedNewReferendum[chainId] = tracks

        return .init(newReferendum: updatedNewReferendum, referendumUpdate: referendumUpdate)
    }

    func disablingNewReferendumNotification(
        for chainId: ChainModel.Id
    ) -> GovernanceNotificationsModel {
        var updatedNewReferendum = newReferendum
        updatedNewReferendum[chainId] = nil

        return .init(newReferendum: updatedNewReferendum, referendumUpdate: referendumUpdate)
    }

    func enablingReferendumUpdateNotification(
        for tracks: Set<TrackIdLocal>,
        chainId: ChainModel.Id
    ) -> GovernanceNotificationsModel {
        var updatedReferendumUpdate = referendumUpdate
        updatedReferendumUpdate[chainId] = tracks

        return .init(newReferendum: newReferendum, referendumUpdate: updatedReferendumUpdate)
    }

    func disablingReferendumUpdateNotification(for chainId: ChainModel.Id) -> GovernanceNotificationsModel {
        var updatedReferendumUpdate = referendumUpdate
        updatedReferendumUpdate[chainId] = nil

        return .init(newReferendum: newReferendum, referendumUpdate: updatedReferendumUpdate)
    }
}

extension GovernanceNotificationsModel {
    init(topicSettings: PushNotification.TopicSettings) {
        var chainReferendumUpdateTopics = [ChainModel.Id: Set<TrackIdLocal>]()
        var chainNewReferendumTopics = [ChainModel.Id: Set<TrackIdLocal>]()

        for topic in topicSettings.topics {
            switch topic {
            case let .chainReferendums(chainId, trackId):
                chainReferendumUpdateTopics[chainId] = chainReferendumUpdateTopics[chainId]?.union([trackId])
                    ?? [trackId]
            case let .newChainReferendums(chainId, trackId):
                chainNewReferendumTopics[chainId] = chainNewReferendumTopics[chainId]?.union([trackId])
                    ?? [trackId]
            default:
                break
            }
        }

        newReferendum = chainNewReferendumTopics
        referendumUpdate = chainReferendumUpdateTopics
    }

    static func empty() -> GovernanceNotificationsModel {
        .init(newReferendum: [:], referendumUpdate: [:])
    }
}

extension PushNotification.TopicSettings {
    func applying(governanceSettings: GovernanceNotificationsModel) -> PushNotification.TopicSettings {
        var topics: Set<PushNotification.Topic> = topics.filter {
            switch $0 {
            case .chainReferendums, .newChainReferendums:
                return false
            case .appCustom:
                return true
            }
        }

        topics = governanceSettings.newReferendum.reduce(
            into: topics
        ) { accum, keyValue in
            let chainId = keyValue.key
            let tracks = keyValue.value

            tracks.forEach { track in
                accum.insert(.newChainReferendums(chainId: chainId, trackId: track))
            }
        }

        topics = governanceSettings.referendumUpdate.reduce(
            into: topics
        ) { accum, keyValue in
            let chainId = keyValue.key
            let tracks = keyValue.value

            tracks.forEach { track in
                accum.insert(.chainReferendums(chainId: chainId, trackId: track))
            }
        }

        return .init(topics: topics)
    }
}
