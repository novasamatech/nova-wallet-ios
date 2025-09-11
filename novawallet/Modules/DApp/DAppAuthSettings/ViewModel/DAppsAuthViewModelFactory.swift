import Foundation

protocol DAppsAuthViewModelFactoryProtocol {
    func createViewModels(
        from authorizationStore: [String: DAppSettings],
        dAppsList: DAppList?
    ) -> [DAppAuthSettingsViewModel]
}

final class DAppsAuthViewModelFactory: DAppsAuthViewModelFactoryProtocol {
    func createViewModels(
        from authorizationStore: [String: DAppSettings],
        dAppsList: DAppList?
    ) -> [DAppAuthSettingsViewModel] {
        let dAppsStore: [String: DApp] = dAppsList?.dApps.reduce(into: [String: DApp]()) { result, dApp in
            if let host = dApp.url.host {
                result[host] = dApp
            }
        } ?? [:]

        return authorizationStore.values.compactMap { auth in
            guard let dappId = auth.dAppId else { return nil }

            let title: String
            let subtitle: String?

            let path = URL(string: dappId)?.path
            let optDApp = dAppsStore[dappId]

            if let dApp = optDApp {
                title = dApp.name
                subtitle = path
            } else {
                title = path ?? ""
                subtitle = nil
            }

            let imageViewModel: ImageViewModelProtocol

            if let iconUrl = optDApp?.icon {
                imageViewModel = RemoteImageViewModel(url: iconUrl)
            } else {
                let icon = R.image.iconDefaultDapp()!
                imageViewModel = StaticImageViewModel(image: icon)
            }

            return DAppAuthSettingsViewModel(
                title: title,
                subtitle: subtitle,
                iconViewModel: imageViewModel,
                identifier: dappId
            )
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
