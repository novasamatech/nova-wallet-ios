import Foundation
import UIKit

protocol DAppBrowserTabListViewModelFactoryProtocol {
    func createViewModels(
        for tabs: [DAppBrowserTab],
        locale: Locale,
        onClose: @escaping (UUID) -> Void
    ) -> [DAppBrowserTabViewModel]
}

struct DAppBrowserTabListViewModelFactory: DAppBrowserTabListViewModelFactoryProtocol {
    func createViewModels(
        for tabs: [DAppBrowserTab],
        locale: Locale,
        onClose: @escaping (UUID) -> Void
    ) -> [DAppBrowserTabViewModel] {
        tabs.map {
            createViewModel(
                for: $0,
                locale: locale,
                onClose
            )
        }
    }

    private func createViewModel(
        for tab: DAppBrowserTab,
        locale: Locale,
        _ onClose: @escaping (UUID) -> Void
    ) -> DAppBrowserTabViewModel {
        let iconViewModel: ImageViewModelProtocol? = {
            guard let iconUrl = tab.icon else { return nil }

            return RemoteImageViewModel(url: iconUrl)
        }()

        let renderViewModel: ImageViewModelProtocol? = {
            guard
                let renderData = tab.stateRender,
                let image = UIImage(data: renderData)
            else {
                return nil
            }

            return StaticImageViewModel(image: image)
        }()

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
            icon: iconViewModel,
            onClose: onClose
        )
    }
}
