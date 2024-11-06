import Foundation

protocol AppearanceDepending: AnyObject {
    var appearanceFacade: AppearanceFacadeProtocol? { get set }
}

private enum AppearanceDependingConstants {
    static var facadeKey = "com.novawallet.appearanceDepending.facade"
}

extension AppearanceDepending {
    var appearanceFacade: AppearanceFacadeProtocol? {
        get {
            objc_getAssociatedObject(self, &AppearanceDependingConstants.facadeKey)
                as? AppearanceFacadeProtocol
        }
        set {
            let appearanceFacade = appearanceFacade

            guard newValue !== appearanceFacade else {
                return
            }

            objc_setAssociatedObject(
                self,
                &AppearanceDependingConstants.facadeKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )

            useIconAppearanceIfNeeded(for: newValue)
        }
    }

    private func useIconAppearanceIfNeeded(for facade: AppearanceFacadeProtocol?) {
        guard let observer = self as? IconAppearanceDepending else {
            return
        }

        facade?.removeObserver(by: observer)
        facade?.addIconApperanceObserver(with: observer)

        observer.applyIconAppearance()
    }
}
