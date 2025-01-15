import Foundation

struct DAppBrowserWidgetModel {
    let title: String?
    let icon: ImageViewModelProtocol?
    let widgetState: DAppBrowserWidgetState
    let transitionBuilder: DAppBrowserWidgetTransitionBuilder?
}
