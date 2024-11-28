import Foundation

protocol DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(
        for tabs: [UUID: DAppBrowserTab],
        state: DAppBrowserWidgetState,
        locale: Locale
    ) -> DAppBrowserWidgetModel
}

class DAppBrowserWidgetViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(
        for tabs: [UUID: DAppBrowserTab],
        state: DAppBrowserWidgetState,
        locale: Locale
    ) -> DAppBrowserWidgetModel {
        let title: String? = if tabs.count > 1 {
            [
                "\(tabs.count)",
                R.string.localizable.tabbarDappsTitle(
                    preferredLanguages: locale.rLanguages
                )
            ].joined(with: .space)
        } else {
            tabs.values.first?.name ?? tabs.values.first?.url.absoluteString
        }

        return DAppBrowserWidgetModel(
            title: title,
            widgetState: state
        )
    }
}
