import Foundation
import Foundation_iOS

final class WalletsChoosePresenter: WalletsListPresenter {
    weak var delegate: WalletsChooseDelegate?

    init(
        delegate: WalletsChooseDelegate,
        interactor: WalletsListInteractorInputProtocol,
        wireframe: WalletsListWireframeProtocol,
        viewModelFactory: WalletsListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.delegate = delegate

        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }
}

extension WalletsChoosePresenter: WalletsChoosePresenterProtocol {
    func selectItem(at index: Int, section: Int) {
        let viewModel = viewModels[section].items[index]

        guard
            !viewModel.isSelected,
            let item = walletsList.allItems.first(where: { $0.identifier == viewModel.identifier }) else {
            return
        }

        delegate?.walletChooseDidSelect(item: item)
    }
}
