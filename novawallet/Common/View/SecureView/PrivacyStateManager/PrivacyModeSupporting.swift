import Foundation

protocol PrivacyModeSupporting: AnyObject {
    var privacyStateManager: PrivacyStateManagerProtocol? { get set }

    func applyPrivacyMode()
}

private enum PrivacyModeSupportingConstants {
    static var managerKey = "com.novawallet.privacyModeSupporting.manager"
}

extension PrivacyModeSupporting {
    var privacyStateManager: PrivacyStateManagerProtocol? {
        get {
            objc_getAssociatedObject(self, &PrivacyModeSupportingConstants.managerKey)
                as? PrivacyStateManagerProtocol
        }
        set {
            let currentManager = privacyStateManager

            guard newValue !== currentManager else {
                return
            }

            currentManager?.removeObserver(by: self)

            newValue?.addObserver(with: self) { [weak self] _, _ in
                self?.applyPrivacyMode()
            }

            objc_setAssociatedObject(
                self,
                &PrivacyModeSupportingConstants.managerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )

            applyPrivacyMode()
        }
    }
}

extension PrivacyModeSupporting {
    var privacyModeEnabled: Bool {
        privacyStateManager?.privacyModeEnabled ?? false
    }
}
