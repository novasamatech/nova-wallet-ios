import Foundation
import Foundation_iOS

final class GiftListPresenter {
    weak var view: GiftListViewProtocol?
    let wireframe: GiftListWireframeProtocol
    let interactor: GiftListInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    let onboardingViewModelFactory: GiftsOnboardingViewModelFactoryProtocol

    let learnMoreUrl: URL

    init(
        interactor: GiftListInteractorInputProtocol,
        wireframe: GiftListWireframeProtocol,
        onboardingViewModelFactory: GiftsOnboardingViewModelFactoryProtocol,
        learnMoreUrl: URL,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.onboardingViewModelFactory = onboardingViewModelFactory
        self.learnMoreUrl = learnMoreUrl
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftListPresenter {
    func provideOnboarding() {
        let viewModel = onboardingViewModelFactory.createViewModel(
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - GiftListPresenterProtocol

extension GiftListPresenter: GiftListPresenterProtocol {
    func setup() {
        view?.didReceive(loading: true)
        interactor.setup()
    }

    func activateLearnMore() {
        guard let view else { return }

        wireframe.showWeb(
            url: learnMoreUrl,
            from: view,
            style: .automatic
        )
    }

    func actionCreateGift() {
        wireframe.showCreateGift(from: view)
    }
}

// MARK: - GiftListInteractorOutputProtocol

extension GiftListPresenter: GiftListInteractorOutputProtocol {
    func didReceive(_ gifts: [GiftModel]) {
        guard !gifts.isEmpty else {
            provideOnboarding()
            return
        }

        print(gifts)
    }

    func didReceive(_: any Error) {
        view?.didReceive(loading: false)

        wireframe.presentRequestStatus(
            on: view,
            locale: localizationManager.selectedLocale,
            retryAction: { [weak self] in
                self?.interactor.setup()
            }
        )
    }
}
