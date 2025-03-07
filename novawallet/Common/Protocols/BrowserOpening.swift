import Foundation
import UIKit

protocol BrowserOpening: BrowserNavigationProtocol {}

extension BrowserOpening {
    func openBrowser(with dAppId: String) {
        guard let browserNavigation = BrowserNavigationFactory.createNavigation() else {
            return
        }

        browserNavigation.openBrowser(with: dAppId)
    }

    func openBrowser(with model: DAppNavigation) {
        guard let browserNavigation = BrowserNavigationFactory.createNavigation() else {
            return
        }

        browserNavigation.openBrowser(with: model)
    }

    func openBrowser(with result: DAppSearchResult) {
        guard let browserNavigation = BrowserNavigationFactory.createNavigation() else {
            return
        }

        browserNavigation.openBrowser(with: result)
    }
}
