import Foundation
import Foundation_iOS

final class GiftPrepareSharePresenter {
    weak var view: GiftPrepareShareViewProtocol?
    let wireframe: GiftPrepareShareWireframeProtocol
    let interactor: GiftPrepareShareInteractorInputProtocol
    let viewModelFactory: GiftPrepareShareViewModelFactoryProtocol

    let localizationManager: LocalizationManagerProtocol

    var chainAsset: ChainAsset?
    var gift: GiftModel?

    init(
        interactor: GiftPrepareShareInteractorInputProtocol,
        wireframe: GiftPrepareShareWireframeProtocol,
        viewModelFactory: GiftPrepareShareViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftPrepareSharePresenter {
    func provideViewModel() {
        guard
            let gift,
            let chainAsset,
            let viewModel = viewModelFactory.createViewModel(
                for: chainAsset,
                gift: gift,
                locale: localizationManager.selectedLocale
            )
        else { return }

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - GiftPrepareSharePresenterProtocol

extension GiftPrepareSharePresenter: GiftPrepareSharePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func actionShare() {
        guard let gift, let chainAsset else { return }

        interactor.share(gift: gift, chainAsset: chainAsset)
    }
}

// MARK: - GiftPrepareShareInteractorOutputProtocol

extension GiftPrepareSharePresenter: GiftPrepareShareInteractorOutputProtocol {
    func didReceive(_ data: GiftPrepareShareInteractorOutputData) {
        chainAsset = data.chainAsset
        gift = data.gift

        provideViewModel()
    }

    func didReceive(_ sharingPayload: GiftSharingPayload) {
        guard let gift, let chainAsset else { return }

        let items = viewModelFactory.createShareItems(
            from: sharingPayload,
            gift: gift,
            chainAsset: chainAsset,
            locale: localizationManager.selectedLocale
        )

        wireframe.share(
            items: items,
            from: view,
            with: nil
        )
    }

    func didReceive(_ error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}
