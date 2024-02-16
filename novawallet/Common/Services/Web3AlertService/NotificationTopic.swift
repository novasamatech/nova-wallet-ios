enum NotificationTopic {
    case appUpdates
    case chainReferendums(chainId: String, trackId: String?)

    var identifier: String {
        switch self {
        case .appUpdates:
            return "appUpdates"
        case let .chainReferendums(chainId, trackId):
            return [
                "chainReferendums",
                chainId,
                trackId
            ].compactMap { $0 }.joined(separator: "-")
        }
    }
}
