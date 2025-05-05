import Foundation
import Keystore_iOS

protocol AppearanceFacadeProtocol: AnyObject {
    var selectedIconAppearance: AppearanceIconsOptions { get set }

    func addIconApperanceObserver(with observer: IconAppearanceDepending)
    func removeObserver(by owner: AnyObject)
}

final class AppearanceFacade {
    private let iconState: Observable<AppearanceIconsOptions>
    private let settings: SettingsManagerProtocol

    public var selectedIconAppearance: AppearanceIconsOptions {
        didSet {
            if oldValue != selectedIconAppearance {
                settings.assetIconsAppearance = selectedIconAppearance

                iconState.state = selectedIconAppearance
            }
        }
    }

    init(settings: SettingsManagerProtocol) {
        self.settings = settings

        let currentIconsAppearance = settings.assetIconsAppearance

        selectedIconAppearance = currentIconsAppearance
        iconState = .init(state: currentIconsAppearance)
    }
}

extension AppearanceFacade {
    static let shared: AppearanceFacadeProtocol = AppearanceFacade(
        settings: SettingsManager.shared
    )
}

// MARK: AppearanceFacadeProtocol

extension AppearanceFacade: AppearanceFacadeProtocol {
    func removeObserver(by owner: AnyObject) {
        iconState.removeObserver(by: owner)
    }

    func addIconApperanceObserver(with observer: IconAppearanceDepending) {
        iconState.addObserver(with: observer) { _, _ in
            observer.applyIconAppearance()
        }
    }
}
