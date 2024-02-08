enum NotificationTopic {
    case appUpdates
    case chainReferendums(chainId: String, trackId: String?, referendumId: String?)

    var identifier: String {
        switch self {
        case .appUpdates:
            return "appUpdates"
        case let .chainReferendums(chainId, trackId, referendumId):
            return [
                "chainReferendums",
                chainId,
                trackId,
                referendumId
            ].compactMap { $0 }.joined(separator: "-")
        }
    }
}
