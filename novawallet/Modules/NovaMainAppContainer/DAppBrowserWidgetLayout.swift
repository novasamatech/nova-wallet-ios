import UIKit

enum DAppBrowserWidgetLayout {
    case closed
    case minimized
    case maximized

    init(from widgetState: DAppBrowserWidgetState) {
        switch widgetState {
        case .disabled:
            self = .closed
        case .closed:
            self = .closed
        case .miniature:
            self = .minimized
        case .fullBrowser:
            self = .maximized
        }
    }
}
