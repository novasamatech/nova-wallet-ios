import Foundation
import UIKit

protocol DAppBrowserTabListViewModelFactoryProtocol {
    func createViewModels(
        for tabs: [DAppBrowserTab],
        locale: Locale
    ) -> [DAppBrowserTabViewModel]
}

struct DAppBrowserTabListViewModelFactory {
    private let imageViewModelFactory: WebViewRenderImageViewModelFactoryProtocol
    private let dAppIconViewModelFactory: DAppIconViewModelFactoryProtocol

    init(
        imageViewModelFactory: WebViewRenderImageViewModelFactoryProtocol,
        dAppIconViewModelFactory: DAppIconViewModelFactoryProtocol
    ) {
        self.imageViewModelFactory = imageViewModelFactory
        self.dAppIconViewModelFactory = dAppIconViewModelFactory
    }

    private func createViewModel(
        for tab: DAppBrowserTab,
        locale: Locale
    ) -> DAppBrowserTabViewModel {
        let iconViewModel = dAppIconViewModelFactory.createIconViewModel(for: tab)
        let renderViewModel = imageViewModelFactory.createViewModel(for: tab.uuid)

        let url = tab.url.host

        let name = if let dAppName = tab.name {
            dAppName
        } else if let url {
            url
        } else {
            R.string(preferredLanguages: locale.rLanguages
            ).localizable.dappBrowserTabNotAvailable()
        }

        return DAppBrowserTabViewModel(
            uuid: tab.uuid,
            stateRender: renderViewModel,
            name: name,
            icon: iconViewModel,
            renderModifiedAt: tab.renderModifiedAt
        )
    }
}

// MARK: DAppBrowserTabListViewModelFactoryProtocol

extension DAppBrowserTabListViewModelFactory: DAppBrowserTabListViewModelFactoryProtocol {
    func createViewModels(
        for tabs: [DAppBrowserTab],
        locale: Locale
    ) -> [DAppBrowserTabViewModel] {
        tabs.map {
            createViewModel(
                for: $0,
                locale: locale
            )
        }
    }
}
