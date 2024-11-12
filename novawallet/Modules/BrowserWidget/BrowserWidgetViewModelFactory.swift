import Foundation

enum DAppBrowserWidgetViewModel: Equatable {
    case empty
    case some(title: String)

    var title: String? {
        switch self {
        case .empty:
            nil
        case let .some(title):
            title
        }
    }
}

protocol BrowserWidgetViewModelFactoryProtocol {
    func createViewModel(for tabs: [UUID: DAppBrowserTabModel]) -> DAppBrowserWidgetViewModel
}

class BrowserWidgetViewModelFactory: BrowserWidgetViewModelFactoryProtocol {
    func createViewModel(for tabs: [UUID: DAppBrowserTabModel]) -> DAppBrowserWidgetViewModel {
        guard let firstTabTitle = tabs.values.first?.url.absoluteString else {
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
