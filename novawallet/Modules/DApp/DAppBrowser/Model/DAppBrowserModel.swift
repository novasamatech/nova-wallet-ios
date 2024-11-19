import Foundation

struct DAppBrowserModel {
    let selectedTab: DAppBrowserTab?
    let isDesktop: Bool
    let transports: [DAppTransportModel]
}
