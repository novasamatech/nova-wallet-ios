import Foundation

protocol DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(
        for tabs: [UUID: DAppBrowserTab],
        state: DAppBrowserWidgetState,
        transitionBuilder: DAppBrowserWidgetTransitionBuilder?,
        locale: Locale
    ) -> DAppBrowserWidgetModel
}

class DAppBrowserWidgetViewModelFactory {
    private let dAppIconViewModelFactory: DAppIconViewModelFactoryProtocol

    init(dAppIconViewModelFactory: DAppIconViewModelFactoryProtocol) {
        self.dAppIconViewModelFactory = dAppIconViewModelFactory
    }
}

// MARK: DAppBrowserWidgetViewModelFactoryProtocol

extension DAppBrowserWidgetViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(
        for tabs: [UUID: DAppBrowserTab],
        state: DAppBrowserWidgetState,
        transitionBuilder: DAppBrowserWidgetTransitionBuilder?,
        locale: Locale
    ) -> DAppBrowserWidgetModel {
        let title: String? = if tabs.count > 1 {
            [
                "\(tabs.count)",
                R.string(preferredLanguages: locale.rLanguages).localizable.tabbarDappsTitle()
            ].joined(with: .space)
        } else {
            tabs.values.first?.name
                ?? tabs.values.first?.url.host
                ?? tabs.values.first?.url.absoluteString
        }

        let iconViewModel: ImageViewModelProtocol? = if tabs.count == 1, let tab = tabs.values.first {
            dAppIconViewModelFactory.createIconViewModel(for: tab)
        } else {
            nil
        }

        return DAppBrowserWidgetModel(
            title: title,
            icon: iconViewModel,
            widgetState: state,
            transitionBuilder: transitionBuilder
        )
    }
}
