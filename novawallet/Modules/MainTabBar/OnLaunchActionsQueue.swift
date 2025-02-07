import Foundation

protocol OnLaunchActionsQueueDelegate: AnyObject {
    func onLaunchProccessPushNotificationsSetup(_ event: OnLaunchAction.PushNotificationsSetup)
}

protocol OnLaunchActionsQueueProtocol {
    func runNext()
}

final class OnLaunchActionsQueue {
    weak var delegate: OnLaunchActionsQueueDelegate?

    private var possibleActions: [OnLaunchActionProtocol]

    init(possibleActions: [OnLaunchActionProtocol]) {
        self.possibleActions = possibleActions
    }
}

extension OnLaunchActionsQueue: OnLaunchActionsQueueProtocol {
    func runNext() {
        guard !possibleActions.isEmpty, let delegate = delegate else {
            return
        }

        let nextAction = possibleActions.removeFirst()

        nextAction.accept(visitor: delegate)
    }
}
