import Foundation

protocol DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(
        for tabs: [UUID: DAppBrowserTab],
        locale: Locale
    ) -> DAppBrowserWidgetViewModel
}

class DAppBrowserWidgetViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(
        for tabs: [UUID: DAppBrowserTab],
        locale: Locale
    ) -> DAppBrowserWidgetViewModel {
        guard let firstTab = tabs.values.first else {
            return .empty
        }

        let title: String = if tabs.count > 1 {
            [
                "\(tabs.count)",
                R.string.localizable.tabbarDappsTitle(
                    preferredLanguages: locale.rLanguages
                )
            ].joined(with: .space)
        } else {
            firstTab.name ?? firstTab.url.absoluteString
        }

        return .some(title: title, count: tabs.count)
    }
}
