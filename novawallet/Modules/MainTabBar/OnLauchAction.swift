import Foundation

protocol OnLaunchActionProtocol {
    func accept(visitor: OnLaunchActionsQueueDelegate)
}

enum OnLaunchAction {
    struct PushNotificationsSetup: OnLaunchActionProtocol {
        func accept(visitor: OnLaunchActionsQueueDelegate) {
            visitor.onLaunchProccessPushNotificationsSetup(self)
        }
    }

    struct MultisigNotificationsPromo: OnLaunchActionProtocol {
        func accept(visitor: OnLaunchActionsQueueDelegate) {
            visitor.onLaunchProcessMultisigNotificationPromo(self)
        }
    }
}
