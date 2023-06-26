import Foundation
import SoraFoundation

final class StartStakingInfoPresenter {
    weak var view: StartStakingInfoViewProtocol?
    let wireframe: StartStakingInfoWireframeProtocol
    let interactor: StartStakingInfoInteractorInputProtocol
    let startStakingViewModelFactory: StartStakingViewModelFactoryProtocol

    init(
        interactor: StartStakingInfoInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.startStakingViewModelFactory = startStakingViewModelFactory
    }
}

extension StartStakingInfoPresenter: StartStakingInfoPresenterProtocol {
    func setup() {
        let title = startStakingViewModelFactory.earnupModel(locale: selectedLocale)
        let wikiUrl = startStakingViewModelFactory.wikiModel(
            locale: selectedLocale,
            url: URL(string: "https://google.com")!
        )
        let termsUrl = startStakingViewModelFactory.termsModel(
            locale: selectedLocale,
            url: URL(string: "https://google.com")!
        )
        let paragraphs = [
            startStakingViewModelFactory.stakeModel(locale: selectedLocale),
            startStakingViewModelFactory.unstakeModel(locale: selectedLocale),
            startStakingViewModelFactory.rewardModel(locale: selectedLocale),
            startStakingViewModelFactory.govModel(locale: selectedLocale),
            startStakingViewModelFactory.recommendationModel(locale: selectedLocale)
        ]
        let stubModel = StartStakingViewModel(
            title: title,
            paragraphs: paragraphs,
            wikiUrl: wikiUrl,
            termsUrl: termsUrl
        )
        view?.didReceive(viewModel: .loaded(value: stubModel))
        view?.didReceive(balance: startStakingViewModelFactory.balance(locale: selectedLocale))
    }
}

extension StartStakingInfoPresenter: StartStakingInfoInteractorOutputProtocol {}

extension StartStakingInfoPresenter: Localizable {
    func applyLocalization() {}
}
