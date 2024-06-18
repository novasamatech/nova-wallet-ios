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

    struct IncreaseWalletsSecurity: OnLaunchActionProtocol {
        func accept(visitor: OnLaunchActionsQueueDelegate) {
            visitor.onLaunchProccessIncreaseSecurity(self)
        }
    }
}
