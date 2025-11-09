import Foundation
import Foundation_iOS

final class GiftClaimPresenter {
    weak var view: GiftClaimViewProtocol?
    let wireframe: GiftClaimWireframeProtocol
    let interactor: GiftClaimInteractorInputProtocol
    let viewModelFactory: GiftClaimViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    var giftDescription: ClaimableGiftDescription?

    init(
        interactor: GiftClaimInteractorInputProtocol,
        wireframe: GiftClaimWireframeProtocol,
        viewModelFactory: GiftClaimViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftClaimPresenter {
    func provideViewModel() {
        guard
            let giftDescription,
            let viewModel = viewModelFactory.createViewModel(
                from: giftDescription,
                locale: localizationManager.selectedLocale
            )
        else { return }

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - GiftClaimPresenterProtocol

extension GiftClaimPresenter: GiftClaimPresenterProtocol {
    func actionClaim() {}

    func actionSelectWallet() {}

    func setup() {
        interactor.setup()
    }
}

// MARK: - GiftClaimInteractorOutputProtocol

extension GiftClaimPresenter: GiftClaimInteractorOutputProtocol {
    func didReceive(_ giftDescription: ClaimableGiftDescription) {
        guard self.giftDescription == nil else { return }

        self.giftDescription = giftDescription

        provideViewModel()
    }

    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}
