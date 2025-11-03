import Foundation

final class GiftPrepareSharePresenter {
    weak var view: GiftPrepareShareViewProtocol?
    let wireframe: GiftPrepareShareWireframeProtocol
    let interactor: GiftPrepareShareInteractorInputProtocol

    let chainAsset: ChainAsset

    let viewModelFactory: GiftPrepareShareViewModelFactoryProtocol

    var gift: GiftModel?

    init(
        interactor: GiftPrepareShareInteractorInputProtocol,
        wireframe: GiftPrepareShareWireframeProtocol,
        viewModelFactory: GiftPrepareShareViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
    }
}

// MARK: - Private

private extension GiftPrepareSharePresenter {
    func provideViewModel() {
        guard let viewModel = viewModelFactory.createViewModel(for: chainAsset.asset) else { return }

        view?.didReceive(viewModel: viewModel)
    }
}

extension GiftPrepareSharePresenter: GiftPrepareSharePresenterProtocol {
    func setup() {
        provideViewModel()
    }
}

extension GiftPrepareSharePresenter: GiftPrepareShareInteractorOutputProtocol {}
