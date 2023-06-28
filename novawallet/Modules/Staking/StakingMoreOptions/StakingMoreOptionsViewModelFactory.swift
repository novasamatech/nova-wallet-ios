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
        createInactiveStakingViewModel(for: model, locale: locale)
    }

    func createDAppModel(for dApp: DApp) -> LoadableViewModelState<DAppView.Model> {
        .loaded(value:
            DAppView.Model(
                icon: dApp.icon.map { RemoteImageViewModel(url: $0) } ?? StaticImageViewModel(image: R.image.iconDefaultDapp()!),
                title: dApp.name,
                subtitle: ""
            ))
    }

    func createLoadingDAppModel() -> [LoadableViewModelState<DAppView.Model>] {
        Array(repeating: .loading, count: 3)
    }
}
