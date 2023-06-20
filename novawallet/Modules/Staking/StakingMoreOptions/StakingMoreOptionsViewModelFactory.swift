import Foundation

protocol StakingMoreOptionsViewModelFactoryProtocol {
    func createStakingViewModel(
        for model: StakingDashboardItemModel,
        locale: Locale
    ) -> StakingDashboardDisabledViewModel

    func createDAppModel(for model: DApp) -> DAppView.Model
}

extension StakingDashboardViewModelFactory: StakingMoreOptionsViewModelFactoryProtocol {
    func createStakingViewModel(
        for model: StakingDashboardItemModel,
        locale: Locale
    ) -> StakingDashboardDisabledViewModel {
        createInactiveStakingViewModel(for: model, locale: locale)
    }

    func createDAppModel(for dApp: DApp) -> DAppView.Model {
        DAppView.Model(
            icon: dApp.icon.map { RemoteImageViewModel(url: $0) } ?? StaticImageViewModel(image: R.image.iconDefaultDapp()!),
            title: dApp.name,
            subtitle: ""
        )
    }
}
