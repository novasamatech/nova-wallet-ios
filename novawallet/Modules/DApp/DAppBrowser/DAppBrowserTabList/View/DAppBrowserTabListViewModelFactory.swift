import Foundation
import UIKit

protocol DAppBrowserTabListViewModelFactoryProtocol {
    func createViewModels(
        for tabs: [DAppBrowserTab],
        locale: Locale
    ) -> [DAppBrowserTabViewModel]
}

struct DAppBrowserTabListViewModelFactory: DAppBrowserTabListViewModelFactoryProtocol {
    private let imageViewModelFactory: WebViewRenderImageViewModelFactoryProtocol

    init(imageViewModelFactory: WebViewRenderImageViewModelFactoryProtocol) {
        self.imageViewModelFactory = imageViewModelFactory
    }

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

    private func createViewModel(
        for tab: DAppBrowserTab,
        locale: Locale
    ) -> DAppBrowserTabViewModel {
        let iconViewModel: ImageViewModelProtocol? = {
            guard let iconUrl = tab.icon else { return nil }

            return RemoteImageViewModel(url: iconUrl)
        }()

        let renderViewModel: ImageViewModelProtocol? = imageViewModelFactory.createViewModel(for: tab.uuid)

        let url = tab.url?.host

        let name = if let dAppName = tab.name {
            dAppName
        } else if let url {
            url
        } else {
            R.string.localizable.dappBrowserTabNotAvailable(
                preferredLanguages: locale.rLanguages
            )
        }

        return DAppBrowserTabViewModel(
            uuid: tab.uuid,
            stateRender: renderViewModel,
            name: name,
            icon: iconViewModel
        )
    }
}
