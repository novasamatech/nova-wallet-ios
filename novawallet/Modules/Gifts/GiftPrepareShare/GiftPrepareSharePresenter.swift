import Foundation
import Foundation_iOS

final class GiftPrepareSharePresenter {
    weak var view: GiftPrepareShareViewProtocol?
    let wireframe: GiftPrepareShareWireframeProtocol
    let interactor: GiftPrepareShareInteractorInputProtocol
    let viewModelFactory: GiftPrepareShareViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    let chainAsset: ChainAsset

    var gift: GiftModel?

    init(
        interactor: GiftPrepareShareInteractorInputProtocol,
        wireframe: GiftPrepareShareWireframeProtocol,
        viewModelFactory: GiftPrepareShareViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftPrepareSharePresenter {
    func provideViewModel() {
        guard
            let gift,
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
}

// MARK: - GiftPrepareShareInteractorOutputProtocol

extension GiftPrepareSharePresenter: GiftPrepareShareInteractorOutputProtocol {
    func didReceive(_ gift: GiftModel) {
        self.gift = gift

        provideViewModel()
    }
}
