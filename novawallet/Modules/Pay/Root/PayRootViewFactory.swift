import Foundation
import Foundation_iOS

struct PayRootViewFactory {
    static func createView() -> ScrollViewHostControlling? {
        PayRootViewController(
            pageProvider: PayPageProvider(),
            localizationManager: LocalizationManager.shared
        )
    }
}
