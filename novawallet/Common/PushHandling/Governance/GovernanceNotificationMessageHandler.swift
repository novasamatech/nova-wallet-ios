typealias GovernanceNotificationMessageHandler = OpenGovernanceUrlParsingService

extension GovernanceNotificationMessageHandler: NotificationMessageHandlerProtocol {
    func handle(message: NotificationMessage, completion: @escaping (Result<PushHandlingScreen, Error>) -> Void) {
        switch message {
        case let .newReferendum(chainId, payload):
            handle(for: chainId, type: nil) {
                completion(.success(.gov(payload.referendumId)))
            }
        case let .referendumUpdate(chainId, payload):
            handle(for: chainId, type: nil) {
                completion(.success(.gov(payload.referendumId)))
            }
        default:
            return
        }
    }
}
