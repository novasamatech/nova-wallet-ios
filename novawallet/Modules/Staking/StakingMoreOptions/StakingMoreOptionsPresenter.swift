import Foundation

final class StakingMoreOptionsPresenter {
    weak var view: StakingMoreOptionsViewProtocol?
    let wireframe: StakingMoreOptionsWireframeProtocol
    let interactor: StakingMoreOptionsInteractorInputProtocol

    init(
        interactor: StakingMoreOptionsInteractorInputProtocol,
        wireframe: StakingMoreOptionsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func provideDAppViewModel(dApps: [DApp]) {
        let viewModels = dApps.map {
            ReferendumDAppView.Model(
                icon: $0.icon.map { RemoteImageViewModel(url: $0) } ?? StaticImageViewModel(image: R.image.iconDefaultDapp()!),
                title: $0.name,
                subtitle: ""
            )
        }

        view?.didReceive(dAppModels: viewModels)
    }

    private func provideError(_: Error) {
        // TODO:
    }
}

extension StakingMoreOptionsPresenter: StakingMoreOptionsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension StakingMoreOptionsPresenter: StakingMoreOptionsInteractorOutputProtocol {
    func didReceive(dAppsResult: Result<DAppList, Error>?) {
        switch dAppsResult {
        case let .success(list):
            provideDAppViewModel(dApps: list.dApps)
        case let .failure(error):
            provideError(error)
        case .none:
            provideDAppViewModel(dApps: [])
        }
    }
}
