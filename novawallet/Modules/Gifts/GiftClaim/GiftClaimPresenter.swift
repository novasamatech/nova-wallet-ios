import Foundation
import Foundation_iOS

final class GiftClaimPresenter {
    weak var view: GiftClaimViewProtocol?
    let wireframe: GiftClaimWireframeProtocol
    let interactor: GiftClaimInteractorInputProtocol
    let viewModelFactory: GiftClaimViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    var giftDescription: ClaimableGiftDescription?
    var giftedWallet: GiftedWalletType?

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
            let giftedWallet,
            let viewModel = viewModelFactory.createViewModel(
                from: giftDescription,
                giftedWallet: giftedWallet,
                locale: localizationManager.selectedLocale
            )
        else { return }

        view?.didReceive(viewModel: viewModel)
    }

    func provideUnpackingViewModel() {
        guard
            let chainAsset = giftDescription?.chainAsset,
            let viewModel = viewModelFactory.createGiftUnpackingViewModel(for: chainAsset)
        else { return }

        view?.didReceiveUnpacking(viewModel: viewModel)
    }
}

// MARK: - GiftClaimPresenterProtocol

extension GiftClaimPresenter: GiftClaimPresenterProtocol {
    func actionClaim() {
        guard let giftDescription else { return }

        view?.didStartLoading()
        interactor.claimGift(with: giftDescription)
    }

    func actionSelectWallet() {}

    func setup() {
        interactor.setup()
    }
}

// MARK: - GiftClaimInteractorOutputProtocol

extension GiftClaimPresenter: GiftClaimInteractorOutputProtocol {
    func didClaimSuccessfully() {
        view?.didStopLoading()
        provideUnpackingViewModel()
    }

    func didReceive(_ claimSetupResult: GiftClaimInteractor.ClaimSetupResult) {
        giftDescription = claimSetupResult.giftDescription
        giftedWallet = claimSetupResult.giftedWallet

        provideViewModel()
    }

    func didReceive(_ error: any Error) {
        view?.didStopLoading()

        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}
