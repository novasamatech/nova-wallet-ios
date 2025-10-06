import Foundation

protocol StakingMoreOptionsViewModelFactoryProtocol {
    func createStakingViewModel(
        for model: StakingDashboardItemModel,
        locale: Locale
    ) -> StakingDashboardDisabledViewModel

    func createDAppModel(for model: DApp) -> LoadableViewModelState<DAppView.Model>

    func createLoadingDAppModel() -> [LoadableViewModelState<DAppView.Model>]
}

extension StakingDashboardViewModelFactory: StakingMoreOptionsViewModelFactoryProtocol {
    func createStakingViewModel(
        for model: StakingDashboardItemModel,
        locale: Locale
    ) -> StakingDashboardDisabledViewModel {
        createInactiveStakingViewModel(
            for: model,
            privacyModeEnabled: false,
            locale: locale
        )
    }

    func createDAppModel(for dApp: DApp) -> LoadableViewModelState<DAppView.Model> {
        let icon: ImageViewModelProtocol = dApp.icon.map { RemoteImageViewModel(url: $0) } ??
            StaticImageViewModel(image: R.image.iconDefaultDapp()!)

        return .loaded(value:
            DAppView.Model(
                icon: icon,
                title: dApp.name,
                subtitle: ""
            )
        )
    }

    func createLoadingDAppModel() -> [LoadableViewModelState<DAppView.Model>] {
        Array(repeating: .loading, count: 3)
    }
}
