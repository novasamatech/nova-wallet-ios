import Foundation
import RobinHood

final class NftListPresenter {
    weak var view: NftListViewProtocol?
    let wireframe: NftListWireframeProtocol
    let interactor: NftListInteractorInputProtocol
    let viewModelFactory: NftListViewModelFactoryProtocol
    let locale: Locale

    private var viewModels: ListDifferenceCalculator<NftListViewModel>

    init(
        interactor: NftListInteractorInputProtocol,
        wireframe: NftListWireframeProtocol,
        viewModelFactory: NftListViewModelFactoryProtocol,
        locale: Locale
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.locale = locale

        let sortingBlock: (NftListViewModel, NftListViewModel) -> Bool = { model1, model2 in
            let createdAt1 = model1.createdAt
            let createdAt2 = model2.createdAt

            return createdAt1.compare(createdAt2) == .orderedDescending
        }

        viewModels = ListDifferenceCalculator(initialItems: [], sortBlock: sortingBlock)
    }
}

extension NftListPresenter: NftListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func numberOfItems() -> Int {
        viewModels.allItems.count
    }

    func nft(at index: Int) -> NftListViewModel {
        viewModels.allItems[index]
    }
}

extension NftListPresenter: NftListInteractorOutputProtocol {
    func didReceiveNft(changes: [DataProviderChange<NftChainModel>]) {
        let viewModelChanges: [DataProviderChange<NftListViewModel>] = changes.map { change in
            switch change {
            case let .insert(newItem):
                let viewModel = viewModelFactory.createViewModel(from: newItem, for: locale)
                return .insert(newItem: viewModel)
            case let .update(newItem):
                let viewModel = viewModelFactory.createViewModel(from: newItem, for: locale)
                return .update(newItem: viewModel)
            case let .delete(deletedIdentifier):
                return .delete(deletedIdentifier: deletedIdentifier)
            }
        }

        viewModels.apply(changes: viewModelChanges)
        view?.didReceive(changes: viewModels.lastDifferences)
    }

    func didReceive(error _: Error) {}
}
