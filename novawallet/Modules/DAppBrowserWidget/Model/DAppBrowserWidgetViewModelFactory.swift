import Foundation

protocol DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(for tabs: [UUID: DAppBrowserTab]) -> DAppBrowserWidgetViewModel
}

class DAppBrowserWidgetViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol {
    func createViewModel(for tabs: [UUID: DAppBrowserTab]) -> DAppBrowserWidgetViewModel {
        let firstTab = tabs.values.first
        let firstTabTitle = firstTab?.name ?? firstTab?.url.absoluteString

        guard let firstTabTitle else {
            return .empty
        }

        let widgetTitle = if tabs.count > 1 {
            "\(firstTabTitle) & \(tabs.count - 1) Other"
        } else {
            firstTabTitle
        }

        return .some(title: widgetTitle)
    }
}
