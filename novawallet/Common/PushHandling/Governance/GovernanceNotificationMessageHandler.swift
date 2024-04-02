typealias GovernanceNotificationMessageHandler = OpenGovernanceUrlParsingService

extension GovernanceNotificationMessageHandler: PushNotificationMessageHandlingProtocol {
    func handle(
        message: NotificationMessage,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        switch message {
        case let .newReferendum(chainId, payload):
            handle(chainId: chainId, referendumIndex: payload.referendumId, completion: completion)
        case let .referendumUpdate(chainId, payload):
            handle(chainId: chainId, referendumIndex: payload.referendumId, completion: completion)
        default:
            return
        }
    }

    private func handle(
        chainId: ChainModel.Id,
        referendumIndex: Referenda.ReferendumIndex,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        let chainClosure: (ChainModel) -> Bool = {
            Web3Alert.createRemoteChainId(from: $0.chainId) == chainId
        }

        handle(targetChainClosure: chainClosure, type: nil) {
            completion(.success(.gov(referendumIndex)))
        }
    }
}
