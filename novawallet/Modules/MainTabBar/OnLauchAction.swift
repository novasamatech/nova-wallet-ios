import Foundation

protocol OnLaunchActionProtocol {
    func accept(visitor: OnLaunchActionsQueueDelegate)
}

enum OnLaunchAction {
    struct LegalConsent: OnLaunchActionProtocol {
        func accept(visitor: OnLaunchActionsQueueDelegate) {
            visitor.onLaunchProcessLegalConsent(self)
        }
    }

    struct AnalyticsConsent: OnLaunchActionProtocol {
        func accept(visitor: OnLaunchActionsQueueDelegate) {
            visitor.onLaunchProcessAnalyticsConsent(self)
        }
    }

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

    struct AHMInfoSetup: OnLaunchActionProtocol {
        func accept(visitor: OnLaunchActionsQueueDelegate) {
            visitor.onLaunchProcessAHMInfoSetup(self)
        }
    }
}
